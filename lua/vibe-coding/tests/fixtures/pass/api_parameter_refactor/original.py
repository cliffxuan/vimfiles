@allocation_router.put(
    "/{cluster}/{name}",
    response_model=Allocation,
    dependencies=[Depends(check_operator_permission)],
)
def update_allocation(cluster: str, name: str, allocation: Allocation):
    key = f"{REDIS_PREFIX}:share:{cluster}:{name}"
    data: str | None = redis_client.get(key)  # type: ignore
    if not data:
        raise HTTPException(status_code=404, detail="Allocation not found")

    # Get existing share data and update the quota
    share_data = json.loads(data)
    share_data["quota_hard_threshold"] = allocation.allocation

    # Save updated share back to Redis
    redis_client.set(key, json.dumps(share_data))

    return allocation