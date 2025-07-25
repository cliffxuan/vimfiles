def calculate_total(items):
    """Calculate the total price of items."""
    total = 0
    for item in items:
        total += item.price * item.quantity
    return total

def process_order(order):
    items = order.get_items()
    return calculate_total(items)