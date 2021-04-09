import os
import sys
filename = sys.argv[1]
print(filename)
os.system("python3 assembler.py %s" % filename)
os.system("python3 miftohex.py %s" % filename.replace("asm", "mif"))