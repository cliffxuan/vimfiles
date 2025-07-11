return {
  name = 'Multiple Hunks',
  description = 'Test applying a diff with multiple separate hunks',
  should_succeed = true,
  tags = { 'complex', 'multiple-hunks' },

  original_content = [[
class Calculator:
    def __init__(self):
        self.result = 0
    
    def add(self, x, y):
        return x + y
    
    def subtract(self, x, y):
        return x - y
    
    def multiply(self, x, y):
        return x * y
    
    def divide(self, x, y):
        return x / y
]],

  diff_content = [[
--- a/calculator.py
+++ b/calculator.py
@@ -1,4 +1,5 @@
 class Calculator:
     def __init__(self):
         self.result = 0
+        self.history = []
     
@@ -12,4 +13,7 @@
     
     def divide(self, x, y):
-        return x / y
+        if y == 0:
+            raise ValueError("Cannot divide by zero")
+        return x / y
]],

  expected_content = [[
class Calculator:
    def __init__(self):
        self.result = 0
        self.history = []
    
    def add(self, x, y):
        return x + y
    
    def subtract(self, x, y):
        return x - y
    
    def multiply(self, x, y):
        return x * y
    
    def divide(self, x, y):
        if y == 0:
            raise ValueError("Cannot divide by zero")
        return x / y
]],

  file_path = 'calculator.py',
}
