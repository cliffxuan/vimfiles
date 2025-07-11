// Example with [[brackets]] that would break Lua syntax
function process(data) {
    console.log("Processing [[data]] with special characters");
    return data.map(item => item.value);
}