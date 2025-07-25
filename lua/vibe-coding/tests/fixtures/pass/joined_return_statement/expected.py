def calculate_total(items):
    if not items:
        return 0
    return sum(item.price for item in items)  # sum up