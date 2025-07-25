function processData(data) {
  const result = [];
  for (let item of data) {
    result.push(item.value);
  }
  return result;
}