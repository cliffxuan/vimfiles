return {
  name = 'Function Signature Change',
  description = 'Test changing a function signature with type annotations',
  should_succeed = true,
  tags = { 'basic', 'function', 'signature' },

  original_content = [[
def update_allocation(cluster: str, name: str, allocation: Allocation):
    """Update allocation for a cluster resource"""
    key = f"{REDIS_PREFIX}:share:{cluster}:{name}"
    data: str | None = redis_client.get(key)
    
    if data is None:
        raise ValueError(f"No allocation found for {cluster}/{name}")
    
    # Update the allocation
    redis_client.set(key, allocation.to_json())
    return True
]],

  diff_content = [[
--- a/allocation.py
+++ b/allocation.py
@@ -1,4 +1,4 @@
-def update_allocation(cluster: str, name: str, allocation: Allocation):
+def update_allocation(cluster: str, name: str, allocation: str):
     """Update allocation for a cluster resource"""
     key = f"{REDIS_PREFIX}:share:{cluster}:{name}"
     data: str | None = redis_client.get(key)
]],

  expected_content = [[
def update_allocation(cluster: str, name: str, allocation: str):
    """Update allocation for a cluster resource"""
    key = f"{REDIS_PREFIX}:share:{cluster}:{name}"
    data: str | None = redis_client.get(key)
    
    if data is None:
        raise ValueError(f"No allocation found for {cluster}/{name}")
    
    # Update the allocation
    redis_client.set(key, allocation.to_json())
    return True
]],

  file_path = 'allocation.py',
}
