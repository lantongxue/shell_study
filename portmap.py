import socket
import threading
import time


def console_print(msg):
    t = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
    print("\033[0;31;40m"+t+"\033[0m"+"\t"+str(msg))

class RemoteServer():
    ls = None
    isConnected = False
    def __init__(self, address: str, port: int):
        self.address = address
        self.port = port
        self.connect()

    def connect(self):
        try:
            self.socket = socket.socket(socket.AF_INET)
            ip = socket.gethostbyname(self.address)
            self.socket.connect((ip, self.port))
            self.isConnected = True
            addr = self.socket.getpeername()
            console_print('RS: '+addr[0]+':'+str(addr[1])+' connected')
            t = threading.Thread(target=self.__recv, name='RS::__recv')
            t.start()
        except Exception as exception:
            self.isConnected = False
            console_print('RS:connect '+str(exception))
    
    def send(self, data):
        self.socket.send(data)
    
    def disconnect(self):
        self.isConnected = False
        self.socket.close()

    def __recv(self):
        _runing = True
        while _runing:
            if self.isConnected == False:
                _runing = False
            else:
                try:
                    data = self.socket.recv(4096)
                    #console_print('RS: '+str(data))
                    if not data:
                        _runing = False
                        self.isConnected = False
                        console_print('RS:__recv disconnected')
                    else:
                        if self.ls is not None:
                            self.ls.send(data)
                except Exception as exception:
                    _runing = False
                    console_print('RS:__recv '+str(exception))
            
                

class LocalServer():

    def __init__(self, address: str, port: int, raddr: str, rport: int):
        self.address = address
        self.port = port
        self.raddr = raddr
        self.rport = rport

    def start(self):
        self.socket = socket.socket(socket.AF_INET)
        self.socket.bind((self.address, self.port))
        self.socket.listen(1024)

        t = threading.Thread(target=self.__accept, name='LS::__accept')
        t.start()
    
    def __accept(self):
        while True:
            client, addr = self.socket.accept()
            console_print('LS: '+addr[0]+':'+str(addr[1])+' connected')

            rs = RemoteServer(address=self.raddr, port=self.rport)
            if rs.isConnected:
                t = threading.Thread(target=self.__recv, args=(client, rs), name='LS::__recv')
                t.start()
            else:
                client.close()
                console_print('LS:__accept '+addr[0]+':'+str(addr[1])+' disconnected')

    def __recv(self, client, rs):
        _runing = True
        while _runing:
           try:
                data = client.recv(4096)
                addr, port = client.getpeername()
                if not data:
                    _runing = False
                    rs.disconnect()
                    console_print('LS:__recv '+addr+':'+str(port)+' disconnected')
                else:
                    #console_print('LS: '+str(data))
                    rs.ls = client
                    if rs.isConnected == False:
                        rs.connect()
                    rs.send(data)
           except Exception as exception:
               _runing = False
               if rs.isConnected:
                   rs.disconnect()
               console_print('LS:__recv '+str(exception))

if __name__ == "__main__":
    ls = LocalServer(address='本地监听地址', port=本地监听端口, raddr='远程地址', rport=远程端口)
    ls.start()
    console_print('服务启动成功')
