# Interactive Snake Game

## Basic Information
This script is purely written in Bash and is useable by any kernel running version 4 and above. The reason behind this is because the use of associated arrays is imperative. No installation instructions are needed; the script can be run directly from a terminal with `bash Snake.sh`, or it can be made executable using `chmod` and run by double-clicking (if that functionality has been enabled).


## Game Details
When the script is run, a gnome-terminal window is opened with the main menu displayed. You can choose from here to start the game, quit, or clear the highscore; which is stored in /home/$USER/.snake_highscore. The controls are simple, just use the arrow keys to move and "P" to pause. During the game, you can press "Q" to bring up a quit game screen, asking if you're sure you want to exit, or you can use Ctrl-C to quit without a prompt. Additionally, you can press the END key to activate cheat mode. When in cheat mode, collision is turned off, but you don't accumulate any score. After starting the game, you are prompted on your difficulty level, and the harder it is, the faster your snake goes and the higher the amount of points you get per apple.

###### Be aware though that capturing key inputs isn't perfect, so you may need to practice a bit to get used to timing the turns so they actually register. 

