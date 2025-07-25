def update_allocation(cluster: str, name: str, allocation: str):
    """Update allocation for a cluster resource"""
    key = f"{REDIS_PREFIX}:share:{cluster}:{name}"
    data: str | None = redis_client.get(key)
    
    if data is None:
        raise ValueError(f"No allocation found for {cluster}/{name}")
    
    # Update the allocation
    redis_client.set(key, allocation.to_json())
    return True