"""
Generic diff parsing and applying module - Python implementation
Implements the same generic logic as the Lua version.
"""

import os
import re
from dataclasses import dataclass
from typing import List, Optional, Tuple


@dataclass
class Hunk:
    """Represents a single hunk in a diff."""

    header: str
    lines: List[str]


@dataclass
class ParsedDiff:
    """Represents a parsed diff with file paths and hunks."""

    old_path: str
    new_path: str
    hunks: List[Hunk]


class Patcher:
    """Generic diff parsing and applying with minimal pattern matching."""

    @staticmethod
    def _preprocess_diff_lines(lines: List[str]) -> List[str]:
        """
        Preprocess diff lines to handle malformed content like missing linebreaks.

        This handles cases like:
        - Hunk headers joined with content: "@@ -10,7 +10,7 @@clusters = get_clusters(platform)"
        - Context lines joined together: "             )except Exception as e:"

        Args:
            lines: Raw diff lines

        Returns:
            Preprocessed lines with proper linebreaks
        """
        processed_lines = []

        for line in lines:
            # Handle hunk headers that are joined with content
            if line.startswith("@@"):
                hunk_match = re.match(r"^(@@ -\d+,?\d* \+\d+,?\d* @@)(.*)$", line)
                if hunk_match:
                    header, content = hunk_match.groups()
                    processed_lines.append(header)
                    if content.strip():  # Only add content if it's not empty
                        # Infer indentation by looking at the next line or context
                        inferred_content = (
                            Patcher._infer_indentation_for_extracted_content(
                                content, lines, processed_lines
                            )
                        )
                        # Add space prefix to make it a proper context line
                        # Only skip if it already has a diff operator (not just spaces)
                        if inferred_content.startswith(("+", "-")):
                            processed_lines.append(inferred_content)
                        else:
                            processed_lines.append(" " + inferred_content)
                else:
                    processed_lines.append(line)
            else:
                # Handle context lines that are joined (common patterns)
                split_lines = Patcher._split_joined_context_lines(line)
                for split_line in split_lines:
                    # If this was a split line and doesn't have proper diff prefix, add space prefix for context
                    if (
                        len(split_lines) > 1
                        and split_line
                        and not split_line.startswith((" ", "+", "-"))
                    ):
                        processed_lines.append(" " + split_line)
                    else:
                        processed_lines.append(split_line)

        return processed_lines

    @staticmethod
    def _infer_indentation_for_extracted_content(
        content: str, all_lines: List[str], processed_so_far: List[str]
    ) -> str:
        """
        Infer the correct indentation for content extracted from a malformed hunk header.

        Args:
            content: The content that was extracted from hunk header
            all_lines: All original diff lines for context
            processed_so_far: Lines processed so far

        Returns:
            Content with inferred indentation
        """
        if not content or content.startswith((" ", "+", "-")):
            return content

        # Look at the current position in all_lines to find next context lines
        current_pos = len(processed_so_far)

        # Look ahead for addition/removal lines to infer indentation (they often have proper indentation)
        for i in range(current_pos, min(current_pos + 5, len(all_lines))):
            line = all_lines[i]

            # Look at removal/addition lines - they often have the correct indentation
            if line.startswith(("-", "+")):
                line_content = line[1:]  # Remove +/- prefix
                if line_content.strip():  # Only if not empty
                    indentation_match = re.match(r"^(\s*)", line_content)
                    if indentation_match:
                        indentation = indentation_match.group(1)
                        if len(indentation) >= 8:  # Reasonable indentation
                            return indentation + content.strip()

        # Look ahead for context lines to infer indentation
        for i in range(current_pos, min(current_pos + 10, len(all_lines))):
            line = all_lines[i]

            # Look for context lines (start with space) or lines that likely have indentation
            if line.startswith(" ") and len(line) > 1:
                # Extract the indentation from this context line
                context_content = line[1:]  # Remove space prefix
                indentation_match = re.match(r"^(\s*)", context_content)
                if indentation_match:
                    indentation = indentation_match.group(1)
                    # If this looks like it could be the same level of indentation
                    if len(indentation) >= 8:  # Reasonable indentation level
                        return indentation + content.strip()

        # Fallback: assume standard indentation based on common patterns
        # If the content looks like it's inside a function or block, use 12 spaces
        if (
            "get_" in content
            or "clusters" in content
            or any(
                keyword in content for keyword in ["if", "for", "try", "with", "except"]
            )
        ):
            return "            " + content.strip()  # 12 spaces

        return content

    @staticmethod
    def _split_joined_context_lines(line: str) -> List[str]:
        """
        Split context lines that have been improperly joined together.

        Common patterns:
        - "             )except Exception as e:" -> ["             )", "        except Exception as e:"]
        - Lines ending with ) followed by keywords like except, if, while, etc.
        - Function definitions joined with docstrings: "def func():\"\"\"docstring\"\"\""

        Args:
            line: Line that might contain joined content

        Returns:
            List of properly split lines
        """
        if not line:
            return [line]

        # Pattern 1: Function definition joined with docstring
        # "def func():"""docstring"""" -> ["def func():", "    \"\"\"docstring\"\"\""]
        func_docstring_pattern = re.compile(
            r'^(\s*def\s+[^:]+:)(""".*?"""|\'\'\'.*?\'\'\')(.*)$', re.DOTALL
        )
        match = func_docstring_pattern.match(line)
        if match:
            func_def, docstring, remainder = match.groups()

            # Extract indentation from function definition
            func_indent_match = re.match(r"^(\s*)", func_def)
            func_indent = func_indent_match.group(1) if func_indent_match else ""

            # Docstring should be indented 4 spaces more than function
            docstring_line = func_indent + "    " + docstring

            result = [func_def, docstring_line]
            if remainder.strip():
                result.append(func_indent + remainder.strip())
            return result

        # Pattern 2: Lines ending with ) followed by Python keywords
        # Look for closing parenthesis/bracket followed by Python control keywords
        joined_pattern = re.compile(
            r"^(\s*.*[)\]}])((?:except|if|elif|else|while|for|try|finally|with|def|class|import|from|return|raise|pass|break|continue|yield|async|await)\b.*)$"
        )

        match = joined_pattern.match(line)
        if match:
            first_part, second_part = match.groups()

            # Special case: for except/finally/else after ), they should be outdented to match try/for/if level
            if second_part.strip().startswith(("except", "finally", "else")):
                # Extract base indentation from first part
                first_indent_match = re.match(r"^(\s*)", first_part)
                if first_indent_match:
                    base_indent = first_indent_match.group(1)
                    # Reduce indentation for except/finally/else (typically 4 spaces less)
                    if len(base_indent) >= 4:
                        except_indent = base_indent[:-4]  # Remove 4 spaces
                        return [first_part, except_indent + second_part.strip()]

            return [first_part, second_part]

        return [line]

    @staticmethod
    def parse_diff(diff_content: str) -> Tuple[Optional[ParsedDiff], Optional[str]]:
        """
        Parse a unified diff block.

        Args:
            diff_content: The string content of the diff

        Returns:
            Tuple of (parsed_diff, error_message)
        """
        # Pre-process diff content to handle malformed hunk headers and joined lines
        original_lines = diff_content.split("\n")
        lines = Patcher._preprocess_diff_lines(original_lines)

        if len(lines) < 3:
            return None, "Diff content is too short to be valid."

        # Parse file paths with generic VCS prefix handling
        old_path_match = re.match(r"^---\s+(.*)$", lines[0])
        new_path_match = re.match(r"^\+\+\+\s+(.*)$", lines[1])

        if not old_path_match or not new_path_match:
            return (
                None,
                f"Could not parse file paths from diff header.\nHeader was:\n{lines[0]}\n{lines[1]}",
            )

        old_path_raw = old_path_match.group(1)
        new_path_raw = new_path_match.group(1)

        # Clean up malformed paths (remove extra leading dashes and spaces)
        old_path_raw = re.sub(r"^-+\s*", "", old_path_raw)

        # Generic VCS prefix removal (any single char followed by slash)
        old_path = re.sub(r"^\w/", "", old_path_raw)
        new_path = re.sub(r"^\w/", "", new_path_raw)

        # Trim trailing whitespace from paths
        old_path = old_path.rstrip()
        new_path = new_path.rstrip()

        diff = ParsedDiff(old_path=old_path, new_path=new_path, hunks=[])

        current_hunk = None
        line_num = 2  # Start after headers (0-based indexing)

        while line_num < len(lines):
            line = lines[line_num]

            # Handle hunk headers
            if line.startswith("@@"):
                if current_hunk:
                    diff.hunks.append(current_hunk)
                current_hunk = Hunk(header=line, lines=[])
            # Handle diff content lines when we have a current hunk
            elif current_hunk:
                # Handle special case: lines like "--- /dev/null" within hunks
                # These represent empty lines in malformed diffs
                if line == "--- /dev/null":
                    current_hunk.lines.append(" ")  # Convert to empty context line
                # Skip other header lines first (they can start with - or + but are longer)
                elif line.startswith(("---", "+++")):
                    pass
                # Direct match for addition/removal/context lines
                elif line.startswith(("+", "-", " ")) or line == " " or line == "":
                    current_hunk.lines.append(line)
                # For any other line that's not empty and not a header, include it
                elif line:
                    current_hunk.lines.append("~" + line)

            line_num += 1

        # Add the last hunk if it exists
        if current_hunk and current_hunk.lines:
            diff.hunks.append(current_hunk)

        if not diff.hunks:
            return None, "Diff contains no hunks or changes."

        return diff, None

    @staticmethod
    def read_file_lines(filepath: str) -> Optional[List[str]]:
        """
        Read file lines, return None if file doesn't exist.

        Args:
            filepath: Path to the file to read

        Returns:
            List of lines or None if file doesn't exist
        """
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                return f.readlines()
        except (FileNotFoundError, IOError):
            return None

    @staticmethod
    def write_file_lines(filepath: str, lines: List[str]) -> bool:
        """
        Write lines to file.

        Args:
            filepath: Path to the file to write
            lines: Lines to write

        Returns:
            True if successful, False otherwise
        """
        try:
            # Create directory if it doesn't exist
            os.makedirs(os.path.dirname(filepath), exist_ok=True)

            with open(filepath, "w", encoding="utf-8") as f:
                f.writelines(lines)
            return True
        except (IOError, OSError):
            return False

    @staticmethod
    def _try_fuzzy_whitespace_matching(
        original_text_lines: List[str], search_lines: List[str]
    ) -> int:
        """
        Try to match lines allowing for differences in leading whitespace.

        This handles cases where diff context lines have different indentation than
        the original file due to missing space prefixes or other formatting issues.

        Args:
            original_text_lines: Original file content without newlines
            search_lines: Lines to search for

        Returns:
            Index where match was found or -1 if no match
        """

        def content_match(search_line: str, original_line: str) -> bool:
            """Check if two lines match, allowing for whitespace differences."""
            # First try exact match
            if search_line == original_line:
                return True

            # Handle empty lines
            if not search_line.strip() and not original_line.strip():
                return True

            # If both have content, check normalized versions
            if search_line.strip() and original_line.strip():
                search_content = search_line.strip()
                original_content = original_line.strip()

                # Exact content match (ignoring leading whitespace)
                if search_content == original_content:
                    return True

                # Allow small differences in indentation (1-2 spaces)
                search_stripped = search_line.lstrip()
                original_stripped = original_line.lstrip()
                if search_stripped == original_stripped:
                    search_indent = len(search_line) - len(search_stripped)
                    original_indent = len(original_line) - len(original_stripped)
                    # Allow up to 2 spaces difference in indentation
                    if abs(search_indent - original_indent) <= 2:
                        return True

            return False

        # Try to find the search pattern with fuzzy whitespace matching
        for i in range(len(original_text_lines) - len(search_lines) + 1):
            match = True
            for j in range(len(search_lines)):
                if not content_match(search_lines[j], original_text_lines[i + j]):
                    match = False
                    break
            if match:
                return i

        return -1

    @staticmethod
    def _adjust_replacement_indentation(
        original_text_lines: List[str],
        found_at: int,
        search_lines: List[str],
        replacement_lines: List[str],
    ) -> List[str]:
        """
        Adjust replacement lines to preserve original indentation when fuzzy whitespace matching was used.

        This handles cases where the search pattern has different indentation than the original file,
        but we want to preserve the original file's indentation in the replacement.

        Args:
            original_text_lines: Original file content without newlines
            found_at: Index where the match was found
            search_lines: Search pattern lines
            replacement_lines: Replacement pattern lines

        Returns:
            Adjusted replacement lines with preserved indentation
        """
        adjusted_lines = []

        for i, repl_line in enumerate(replacement_lines):
            if i < len(search_lines):
                # This replacement line corresponds to a search line
                search_line = search_lines[i]
                original_line = (
                    original_text_lines[found_at + i]
                    if found_at + i < len(original_text_lines)
                    else ""
                )

                # If the search line and replacement line have the same content (just context)
                # and the original line has different indentation, preserve the original indentation
                if (
                    search_line.strip() == repl_line.strip()
                    and search_line.strip() == original_line.strip()
                    and search_line.strip()
                ):  # Not empty
                    # Extract original indentation
                    original_indent = original_line[
                        : len(original_line) - len(original_line.lstrip())
                    ]
                    repl_content = repl_line.lstrip()
                    adjusted_lines.append(original_indent + repl_content)
                else:
                    # For non-context lines or lines with different content, use as-is
                    adjusted_lines.append(repl_line)
            else:
                # This is a new line being added, use as-is
                adjusted_lines.append(repl_line)

        return adjusted_lines

    @staticmethod
    def _try_joined_statement_matching_with_info(
        original_text_lines: List[str], search_lines: List[str]
    ) -> Tuple[int, Optional[dict]]:
        """
        Try to match joined statements by splitting them, returning match info.

        This handles cases where diff contains malformed lines like "if not items:return 0"
        while the original file has them properly formatted on separate lines.

        Args:
            original_text_lines: Original file content without newlines
            search_lines: Lines to search for

        Returns:
            Tuple of (index where match was found or -1, match info dict or None)
        """
        # Pattern for common joined statements: condition:statement
        joined_pattern = re.compile(
            r"^(\s*)(if|while|for|elif|else|try|except|finally|with)([^:]*:)(.+)$"
        )

        for search_idx, search_line in enumerate(search_lines):
            match = joined_pattern.match(search_line)
            if match:
                indent, keyword, condition_part, statement_part = match.groups()

                # Split into separate lines
                split_line1 = indent + keyword + condition_part
                split_line2 = (
                    indent + "    " + statement_part.strip()
                )  # Add extra indentation for statement

                # Try to find this split pattern in the original file
                for i in range(len(original_text_lines) - len(search_lines)):
                    # Check if we can match by substituting the joined line with split lines
                    match_found = True
                    orig_offset = 0

                    for j, search_line_check in enumerate(search_lines):
                        if j == search_idx:
                            # This is the joined line - check if original has it split
                            if (
                                i + orig_offset < len(original_text_lines)
                                and i + orig_offset + 1 < len(original_text_lines)
                                and original_text_lines[i + orig_offset] == split_line1
                                and original_text_lines[i + orig_offset + 1]
                                == split_line2
                            ):
                                orig_offset += 2  # Skip both lines in original
                            else:
                                match_found = False
                                break
                        else:
                            # Regular line - must match exactly
                            if (
                                i + orig_offset >= len(original_text_lines)
                                or original_text_lines[i + orig_offset]
                                != search_line_check
                            ):
                                match_found = False
                                break
                            orig_offset += 1

                    if match_found:
                        return i, {
                            "joined_search_idx": search_idx,
                            "split_line1": split_line1,
                            "split_line2": split_line2,
                            "original_lines_consumed": orig_offset,
                        }

        return -1, None

    @staticmethod
    def _apply_joined_replacement(
        original_lines: List[str],
        found_at: int,
        search_lines: List[str],
        replacement_lines: List[str],
        joined_match_info: dict,
    ) -> List[str]:
        """
        Apply replacement when we have joined statements that need special handling.

        Args:
            original_lines: Original file lines with newlines
            found_at: Index where match was found
            search_lines: Search pattern lines
            replacement_lines: Replacement pattern lines
            joined_match_info: Info about the joined statement match

        Returns:
            List of replacement lines with proper newlines
        """
        result = []
        search_idx = 0
        replacement_idx = 0
        original_idx = found_at

        while search_idx < len(search_lines) and replacement_idx < len(
            replacement_lines
        ):
            if search_idx == joined_match_info["joined_search_idx"]:
                # This is the joined line in search - it corresponds to 2 original lines
                # But only 1 replacement line. Use the original split format.
                if replacement_idx < len(replacement_lines):
                    repl_line = replacement_lines[replacement_idx]

                    # Check if the replacement line is also joined
                    joined_pattern = re.compile(
                        r"^(\s*)(if|while|for|elif|else|try|except|finally|with)([^:]*:)(.+)$"
                    )
                    repl_match = joined_pattern.match(repl_line)

                    if repl_match:
                        # Replacement is also joined - split it using original format
                        indent, keyword, condition_part, statement_part = (
                            repl_match.groups()
                        )
                        split_line1 = indent + keyword + condition_part
                        split_line2 = indent + "    " + statement_part.strip()
                        result.append(split_line1 + "\n")
                        result.append(split_line2 + "\n")
                    else:
                        # Replacement is not joined - use as-is, but preserve original split structure
                        # This handles cases where the replacement is just a comment addition
                        result.append(repl_line + "\n")

                    replacement_idx += 1
                original_idx += 2  # Skip both original lines
            else:
                # Regular line matching
                if replacement_idx < len(replacement_lines):
                    result.append(replacement_lines[replacement_idx] + "\n")
                    replacement_idx += 1
                original_idx += 1

            search_idx += 1

        # Add any remaining replacement lines
        while replacement_idx < len(replacement_lines):
            result.append(replacement_lines[replacement_idx] + "\n")
            replacement_idx += 1

        return result

    @staticmethod
    def apply_hunk(
        original_lines: List[str], hunk: Hunk
    ) -> Tuple[bool, Optional[List[str]], str]:
        """
        Apply a single hunk to original file lines using search-and-replace strategy.

        Args:
            original_lines: Original file content as lines
            hunk: The hunk to apply

        Returns:
            Tuple of (success, modified_lines, message)
        """
        if not hunk.lines:
            return False, None, "Empty hunk"

        # Build search and replacement patterns like the Lua version
        search_lines = []
        replacement_lines = []

        # Process hunk lines to build search and replacement patterns
        # We need to be careful about trailing empty lines after additions
        addition_found = False

        for i, line in enumerate(hunk.lines):
            if line == "" or line == " ":
                # Check if this empty line comes right before additions (likely represents trailing newline)
                next_line_is_addition = i + 1 < len(hunk.lines) and hunk.lines[
                    i + 1
                ].startswith("+")
                # Or if it comes after an addition and is at the end
                trailing_after_addition = addition_found and i == len(hunk.lines) - 1

                if next_line_is_addition or trailing_after_addition:
                    # This empty line likely represents file structure, not actual content
                    # Add to replacement but be careful about search
                    if trailing_after_addition:
                        # Skip entirely for trailing empty lines after additions
                        pass
                    else:
                        # For empty lines before additions, add to replacement only
                        replacement_lines.append("")
                else:
                    # Regular empty context lines that exist in the file
                    search_lines.append("")
                    replacement_lines.append("")
            elif line.startswith(" "):
                # Context lines go in both search and replacement
                text = line[1:]  # Remove space prefix
                search_lines.append(text)
                replacement_lines.append(text)
            elif line.startswith("-"):
                # Removal lines only go in search pattern
                text = line[1:]  # Remove - prefix
                search_lines.append(text)
                # Do NOT add to replacement_lines - these are removed
            elif line.startswith("+"):
                # Addition lines only go in replacement pattern
                text = line[1:]  # Remove + prefix
                replacement_lines.append(text)
                # Do NOT add to search_lines - these are new content
                addition_found = True
            elif line.startswith("~"):
                # Fixed context lines (missing space prefix)
                text = line[1:]  # Remove ~ prefix
                search_lines.append(text)
                replacement_lines.append(text)

        if not search_lines:
            # Pure addition case - append to end of file
            modified_lines = original_lines[:]
            for line in replacement_lines:
                modified_lines.append(line + "\n")
            return True, modified_lines, "Applied pure addition hunk"

        # Convert original lines to text (without newlines for matching)
        original_text_lines = [line.rstrip("\n") for line in original_lines]

        # Find the search pattern in the original file
        found_at = -1

        # First try exact matching
        for i in range(len(original_text_lines) - len(search_lines) + 1):
            match = True
            for j in range(len(search_lines)):
                if original_text_lines[i + j] != search_lines[j]:
                    match = False
                    break
            if match:
                found_at = i
                break

        # If exact matching fails, try fuzzy matching (ignoring blank lines)
        if found_at == -1:
            # Filter out empty lines from search pattern for fuzzy matching
            non_empty_search_lines = [line for line in search_lines if line.strip()]

            if len(non_empty_search_lines) > 0:
                for i in range(len(original_text_lines)):
                    # Try to match non-empty lines with possible blank lines in between
                    search_idx = 0
                    orig_idx = i

                    while search_idx < len(non_empty_search_lines) and orig_idx < len(
                        original_text_lines
                    ):
                        # Skip empty lines in original
                        while (
                            orig_idx < len(original_text_lines)
                            and not original_text_lines[orig_idx].strip()
                        ):
                            orig_idx += 1

                        if orig_idx >= len(original_text_lines):
                            break

                        # Check if current non-empty line matches
                        if (
                            original_text_lines[orig_idx]
                            == non_empty_search_lines[search_idx]
                        ):
                            search_idx += 1
                            orig_idx += 1
                        else:
                            break

                    # If we matched all non-empty search lines, we found it
                    if search_idx == len(non_empty_search_lines):
                        found_at = i
                        break

        # If fuzzy matching also fails, try fuzzy whitespace matching
        used_fuzzy_whitespace = False
        if found_at == -1:
            found_at = Patcher._try_fuzzy_whitespace_matching(
                original_text_lines, search_lines
            )
            if found_at != -1:
                used_fuzzy_whitespace = True

        # If fuzzy whitespace matching also fails, try joined statement splitting
        joined_match_info = None
        if found_at == -1:
            found_at, joined_match_info = (
                Patcher._try_joined_statement_matching_with_info(
                    original_text_lines, search_lines
                )
            )

        if found_at == -1:
            return (
                False,
                None,
                "Could not find this context in the file",
            )

        # Apply the replacement
        modified_lines = []

        # Add lines before the match
        for i in range(found_at):
            modified_lines.append(original_lines[i])

        # Handle replacement based on whether we have joined statements
        if joined_match_info:
            # Special handling for joined statements
            modified_lines.extend(
                Patcher._apply_joined_replacement(
                    original_lines,
                    found_at,
                    search_lines,
                    replacement_lines,
                    joined_match_info,
                )
            )
            # Calculate how many original lines were consumed
            start_after = found_at + joined_match_info["original_lines_consumed"]
        else:
            # Normal replacement
            if used_fuzzy_whitespace:
                # When fuzzy whitespace matching was used, preserve original indentation
                adjusted_replacement_lines = Patcher._adjust_replacement_indentation(
                    original_text_lines, found_at, search_lines, replacement_lines
                )
                replacement_to_use = adjusted_replacement_lines
            else:
                # Standard replacement
                replacement_to_use = replacement_lines

            # Add replacement lines with proper newline handling
            replacing_to_end = found_at + len(search_lines) == len(original_lines)
            original_ends_with_newline = original_lines and original_lines[-1].endswith(
                "\n"
            )

            # Find the last non-empty replacement line
            last_content_line_idx = len(replacement_to_use) - 1
            while (
                last_content_line_idx >= 0
                and replacement_to_use[last_content_line_idx] == ""
            ):
                last_content_line_idx -= 1

            for i, line in enumerate(replacement_to_use):
                if replacing_to_end and i > last_content_line_idx:
                    # Skip trailing empty lines when replacing to the end of file
                    continue
                elif (
                    replacing_to_end
                    and i == last_content_line_idx
                    and not original_ends_with_newline
                ):
                    # This is the last content line and original didn't end with newline
                    modified_lines.append(line)
                else:
                    # Normal case - add newline
                    modified_lines.append(line + "\n")
            start_after = found_at + len(search_lines)

        # Add lines after the match
        for i in range(start_after, len(original_lines)):
            modified_lines.append(original_lines[i])

        return True, modified_lines, f"Applied hunk at line {found_at + 1}"

    @staticmethod
    def apply_diff(parsed_diff: ParsedDiff) -> Tuple[bool, str]:
        """
        Apply a parsed diff to the target file.

        Args:
            parsed_diff: The parsed diff to apply

        Returns:
            Tuple of (success, message)
        """
        if parsed_diff.new_path == "/dev/null":
            return True, f"Skipped file deletion for {parsed_diff.old_path}"

        # Read the original file
        is_new_file = parsed_diff.old_path == "/dev/null"
        if is_new_file:
            original_lines = []
        else:
            original_lines = Patcher.read_file_lines(parsed_diff.old_path)
            if original_lines is None:
                return False, f"Failed to read file {parsed_diff.old_path}"

        # Apply each hunk
        current_lines = original_lines
        applied_hunks = 0

        for i, hunk in enumerate(parsed_diff.hunks):
            success, modified_lines, message = Patcher.apply_hunk(current_lines, hunk)
            if success:
                current_lines = modified_lines
                applied_hunks += 1
            else:
                return False, f"Failed to apply hunk {i + 1}: {message}"

        # Write the modified file
        if not Patcher.write_file_lines(parsed_diff.new_path, current_lines):
            return False, f"Failed to write file {parsed_diff.new_path}"

        return (
            True,
            f"Successfully applied {applied_hunks} hunks to {parsed_diff.new_path}",
        )
