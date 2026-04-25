serialPortName = "COM3";
baudRate = 115200;
rendererHost = "127.0.0.1";
rendererPort = 9000;

sp = serialport(serialPortName, baudRate);
configureTerminator(sp, "LF");
flush(sp);

client = tcpclient(rendererHost, rendererPort, "Timeout", 5);

disp("Serial to TCP bridge running. Press Ctrl+C in MATLAB to stop.");
while true
    line = readline(sp);
    if strlength(strtrim(line)) == 0
        continue;
    end
    write(client, uint8(char(line + newline)), "uint8");
end
