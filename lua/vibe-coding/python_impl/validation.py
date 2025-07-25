"""
Generic diff validation module - Python implementation
Implements the same generic validation logic as the Lua version.
"""

import re
from dataclasses import dataclass
from typing import List, Optional, Tuple


@dataclass
class Issue:
    """Represents a validation issue found in diff content."""

    line: int
    type: str
    message: str
    severity: str = "info"
    original_text: Optional[str] = None
    split_lines: Optional[List[str]] = None


class Validation:
    """Generic diff validation with minimal pattern matching."""

    @staticmethod
    def try_fix_missing_context_prefix(
        line: str, line_num: int
    ) -> Tuple[Optional[str], Optional[Issue]]:
        """
        Generic approach: if line is not empty and doesn't start with +/-, treat as context.

        Args:
            line: The line to potentially fix
            line_num: The line number for error reporting

        Returns:
            Tuple of (fixed_line, issue) or (None, None) if can't fix
        """
        # Generic approach: if line is not empty and doesn't start with +/-, treat as context
        if line and not re.match(r"^[+-]", line):
            fixed_line = " " + line
            message = f"Added missing space prefix for context line: {line[:50]}"
            if len(line) > 50:
                message += "..."

            issue = Issue(
                line=line_num, type="context_fix", message=message, severity="info"
            )
            return fixed_line, issue

        return None, None

    @staticmethod
    def fix_hunk_content_line(line: str, line_num: int) -> Tuple[str, Optional[Issue]]:
        """
        Generic hunk content line fixing.

        Args:
            line: The line to fix
            line_num: The line number

        Returns:
            Tuple of (fixed_line, issue)
        """
        # Handle empty lines - they're valid as-is
        if not line:
            return line, None

        # Handle valid diff operators
        if line.startswith((" ", "-", "+")):
            return line, None

        # Skip header-like lines that should be ignored (not treated as context)
        if line.startswith(("---", "+++")):
            return line, None

        # Try to fix context lines missing the leading space
        fixed_line, issue = Validation.try_fix_missing_context_prefix(line, line_num)
        if fixed_line:
            return fixed_line, issue

        # If we can't fix it, report as invalid
        return line, Issue(
            line=line_num,
            type="invalid_line",
            message=f"Invalid line in hunk: {line}",
            severity="warning",
        )

    @staticmethod
    def validate_and_fix_diff(diff_content: str) -> Tuple[str, List[Issue]]:
        """
        Generic diff validation and fixing.

        Args:
            diff_content: The raw diff content to validate

        Returns:
            Tuple of (cleaned_diff_content, issues_found)
        """
        lines = diff_content.split("\n")
        issues = []
        fixed_lines = []

        # Track state for validation
        has_header = False
        in_hunk = False

        for i, line in enumerate(lines):
            fixed_line = line
            line_num = i + 1  # 1-based line numbers

            # Check for diff headers
            if line.startswith("---") or line.startswith("+++"):
                has_header = True
                fixed_line, issue = Validation._fix_header_line(line, line_num)
                if issue:
                    issues.append(issue)
            # Check for hunk headers
            elif line.startswith("@@"):
                in_hunk = True
                fixed_line, issue = Validation._fix_hunk_header(line, line_num)
                if issue:
                    issues.append(issue)
            # Check context and change lines
            elif in_hunk:
                fixed_line, issue = Validation.fix_hunk_content_line(line, line_num)
                if issue:
                    issues.append(issue)

            fixed_lines.append(fixed_line)

        # Final validation
        if not has_header:
            issues.append(
                Issue(
                    line=1,
                    type="missing_header",
                    message="Diff missing file headers",
                    severity="error",
                )
            )

        return "\n".join(fixed_lines), issues

    @staticmethod
    def _fix_header_line(line: str, line_num: int) -> Tuple[str, Optional[Issue]]:
        """Fix header line issues."""
        if re.match(r"^---\s*$", line):
            return "--- /dev/null", Issue(
                line=line_num, type="header", message="Fixed empty old file header"
            )
        elif re.match(r"^\+\+\+\s*$", line):
            return "+++ /dev/null", Issue(
                line=line_num, type="header", message="Fixed empty new file header"
            )
        return line, None

    @staticmethod
    def _fix_hunk_header(line: str, line_num: int) -> Tuple[str, Optional[Issue]]:
        """Fix hunk header issues."""
        # Try to parse hunk header
        match = re.match(r"^@@ -(\d+),?(\d*) \+(\d+),?(\d*) @@", line)

        if not match:
            # Try simpler format without counts
            simple_match = re.match(r"^@@ -(\d+) \+(\d+) @@", line)
            if simple_match:
                old_start, new_start = simple_match.groups()
                return f"@@ -{old_start},1 +{new_start},1 @@", Issue(
                    line=line_num,
                    type="hunk_header",
                    message="Added missing line counts",
                )
            else:
                # Check for malformed headers
                if line.startswith("@@ "):
                    return "@@ -1,1 +1,1 @@", Issue(
                        line=line_num,
                        type="hunk_header",
                        message="Normalized malformed hunk header (line numbers ignored for search-and-replace)",
                        severity="info",
                    )
                else:
                    return line, Issue(
                        line=line_num,
                        type="hunk_header",
                        message="Invalid hunk header format",
                        severity="error",
                    )

        return line, None
