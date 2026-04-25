host = "127.0.0.1";
port = 9000;
client = tcpclient(host, port, "Timeout", 5);

for k = 1:200
    frame.frame_id = k;
    frame.origin = struct("x", 960, "y", 540);
    frame.green = struct("x", 1110, "y", 540, "radius", 36);
    frame.red = struct( ...
        "x", 880 + 140 * cos(k * 0.05), ...
        "y", 620 + 90 * sin(k * 0.06), ...
        "radius", 42);
    frame.blue = struct( ...
        "x", frame.red.x + 55 * cos(k * 0.13), ...
        "y", frame.red.y - 65 + 40 * sin(k * 0.11), ...
        "radius", 58);

    line = jsonencode(frame) + newline;
    write(client, uint8(char(line)), "uint8");
    pause(0.03);
end
