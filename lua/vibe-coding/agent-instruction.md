# Coding Agent Instructions

## Testing Requirements
1. **Create comprehensive test cases** for all new functionality
   - Prefer using fixtures over hardcoded values for better readability and maintainability
   - Include edge cases, error conditions, and boundary value tests
   - Follow existing test patterns and naming conventions in the codebase

2. **Maintain test suite integrity**
   - Ensure all existing tests continue to pass after changes
   - If tests were failing before your changes, do not introduce additional failures
   - Run the full test suite to verify compatibility
   - Update or fix any tests that are legitimately broken by necessary changes

## Code Quality Standards
3. **Static analysis compliance**
   - Run lua-language-server and resolve all errors and warnings
   - Pay attention to type annotations, undefined variables, and API usage
   - Ensure code follows Lua best practices and conventions

4. **Code formatting**
   - Run stylua to ensure consistent code formatting
   - Fix any formatting issues before submitting changes
   - Maintain consistency with existing code style in the project

5. **Lua compatibility**
   - Stick to Lua 5.1 syntax and features (Neovim's Lua version)
   - Avoid newer Lua features like `goto` statements, bitwise operators (`&`, `|`, `~`), or integer division (`//`)
   - Use LuaJIT-compatible patterns and avoid features that may not be available

## Design Principles

6. **Favor generic solutions over bespoke pattern matching**
   - Avoid hard-coded patterns, regex rules, or language-specific assumptions
   - Don't try to "understand" code semantics - treat content as generic text
   - Use configurable, data-driven approaches instead of embedded logic
   - Prefer simple algorithms that work across different content types
   - When you find yourself writing pattern-specific logic, step back and look for a more general solution

## General Guidelines
- Always test your changes thoroughly before considering them complete
- Preserve existing functionality unless explicitly asked to modify it
- Document any breaking changes or new APIs clearly
- When in doubt, ask for clarification rather than making assumptions
