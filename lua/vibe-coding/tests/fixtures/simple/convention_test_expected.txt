// Example with [[brackets]] that would break Lua syntax
function process(data) {
    console.log("Processing [[enhanced data]] with special characters");
    return data.map(item => item.value);
}