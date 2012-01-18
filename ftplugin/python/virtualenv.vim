python << EOF
import sys
import vim
try:
    PYTHONPATH=vim.eval("""system('python -c "import sys; print sys.path"')""")
    PYTHONPATH=PYTHONPATH.strip()
    PYTHONPATH=eval(PYTHONPATH) 
    runtime_path = sys.path
    runtime_path.reverse()
    for p in runtime_path:
        if p not in PYTHONPATH:
            PYTHONPATH.insert(0,p)
    sys.path = PYTHONPATH
except:
    pass
EOF
