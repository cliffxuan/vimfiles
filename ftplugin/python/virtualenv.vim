python << EOF
import sys
import vim
try:
    #TODO this is not working for gvim launched from cygwin
    #error: can't open file c:/Docume~1/Cliffx~/Locals~/Temp/VIo40.tmp
    PYTHONPATH=vim.eval("""system('python -c "import sys; print sys.path"')""")
    PYTHONPATH=PYTHONPATH.strip()
    pythonpath=eval(pythonpath) 
    runtime_path = sys.path
    runtime_path.reverse()
    for p in runtime_path:
        if p not in pythonpath:
            pythonpath.insert(0,p)
    sys.path = pythonpath
except:
    pass
EOF
