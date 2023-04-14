import os
import logging
import time
import sys
from datetime import datetime

logging.basicConfig(filename='controller.log',level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")

EXEVERS=False

def main():
    if sys.platform.startswith('win'):
        if EXEVERS:
            status = os.system("\"Server.exe\" 2>> error.log")
        else:
            status = os.system("\"Server.py\" 2>> error.log")
    else:
        status = os.system("python ./Server.py 2>> ./error.log")
    logging.info("Server stopped with a status code of: "+str(status))
    #             Windows               Linux
    if str(status)=="5" or str(status)=="1280":
        print str(datetime.today())+" [Controller] Server stopped."
        os._exit(0)
    elif str(status)=="10" or str(status)=="2560":
        print str(datetime.today())+" [Controller] Server restarted."
        status=""
        main()
    elif str(status)=="11" or str(status)=="2816":
        print str(datetime.today())+" [Controller] Server restarted to clear error log."
        if sys.platform.startswith('win'):
            os.system("del error.log")
        else:
            os.system("rm ./error.log")
        status=""
        main()
    else:
        print str(datetime.today())+" [Controller] Server crashed, restarting in 10 seconds."
        time.sleep(10)
        status=""
        main()

if __name__ == '__main__':
    main()
