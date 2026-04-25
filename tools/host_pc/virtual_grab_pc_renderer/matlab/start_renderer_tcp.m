pythonExe = "F:\codex\Python313\python.exe";
scriptPath = "F:\codex\虚拟物品抓取\pc_renderer\src\main.py";
command = sprintf('start "" "%s" "%s" --input tcp --tcp-port 9000', pythonExe, scriptPath);
system(command);
