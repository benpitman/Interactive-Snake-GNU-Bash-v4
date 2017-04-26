#!/bin/bash

# Creates a copy of the script to tmp for it to be executed in a new terminal
sed -n '8,$p' $0 >| /tmp/snake
gnome-terminal --title "Snake" --geometry 39x20+800+350 -e 'bash /tmp/snake' 2>/dev/null
exit

extrap() {
    rm /tmp/snake
}

populate() {
    for row in {1..18}; do
        for col in {1..37}; do
            tail[$col,$row]=" "
        done
    done
}

show_grid() {
    echo -e '+-------------------------------------+'
    for row in {1..18}; do
        # If snake is not on this row, print an empty row to save time
        if (($ref_row!=$row)) && ! [[ " ${tail_row[@]} " =~ " $row " ]]; then
            echo '|                                     |'
            continue
        fi
        echo -n '|'
        for col in {1..37}; do
            # Print "X" on current position
            if (($ref_col==$col && $ref_row==$row)); then
                echo -n "X"
                continue
            fi
            # Print "x" or " " depending on tail position
            echo -n "${tail[$col,$row]}"
        done
        echo '|'
    done
    echo -n '+-------------------------------------+'
}

navigate() {
    # Current position
    ref_col=20
    ref_row=10
    speed=9
    direction=$(($RANDOM%4))
    tail_len=3
    tail_col=()
    tail_row=()
    while true; do
        # Add current position to the first tail position
        tail_col+=($ref_col)
        tail_row+=($ref_row)
        tail[$ref_col,$ref_row]='x'
        # If the tail reaches the length
        if ((${#tail_col[@]}>$tail_len)); then
            tail[${tail_col[@]:0:1},${tail_row[@]:0:1}]=' '
            tail_col=(${tail_col[@]:1})
            tail_row=(${tail_row[@]:1})
        fi
        tput reset
        show_grid
        # Arrow keys are three characters long
        read -sn1 -t0.$speed key1
        # Refresh the screen every second to update timer
        read_pid=$?
        read -sn1 -t 0.0001 key2
        read -sn1 -t 0.0001 key3
        # Change direction of snake depending on arrow key
        case "$key3" in
           A)   direction=0;; # Up
           B)   direction=1;; # Down
           C)   direction=2;; # Right
           D)   direction=3;; # Left
        esac
        # Increment/Decrement position accoringly
        case "$direction" in
            0)  ((ref_row--));;
            1)  ((ref_row++));;
            2)  ((ref_col+=2));; # Col width is 2 times the size of row
            3)  ((ref_col-=2));;
        esac
        case "$key1" in
            h|p)    pause_time_start=$(date '+%s')
                    pause
                    pause_time_finish=$(date '+%s')
                    ((start_time+=$(($pause_time_finish-$pause_time_start))));;
            q)      quit_reset "quit";;
            r)      quit_reset "reset";;
                    # Colour range: Yellow(33) Blue(34) Purple(35) Cyan(36) White(37)
            s)      colour_num=$(($colour_num==37?33:$colour_num+1));;
        esac
        unset key1 key2 key3
    done
}

show_help() {
    echo -e '|               \e[1mCONTROLS\e[0m              |
            \r|                                     |
            \r|    Arrow Keys    -    Move          |
            \r|      P or H      -    Help          |
            \r|        R         -    Restart       |
            \r|        S         -    Colour        |
            \r|   Q or Ctrl-C    -    Quit          |'
}

main_menu() {
    # Display the main menu
    selected=1
    while true; do
        tput reset
        case $selected in
            1)  START='\e[1;36mSTART\e[0m'
                QUIT='QUIT';;
            0)  START='START'
                QUIT='\e[1;36mQUIT\e[0m';;
        esac
        echo -en "+-------------------------------------+
            \r|                                     |
            \r|            Ben  Pitman's            |
            \r|                                     |
            \r|              \e[1mS N A K E\e[0m              |
            \r|                                     |
            \r|                                     |
            \r$(show_help)
            \r|                                     |
            \r|                                     |
            \r|                                     |
            \r|           $START      $QUIT           |
            \r|                                     |
            \r+-------------------------------------+"
        read -sn1 key1
        read -sn1 -t 0.0001 key2
        read -sn1 -t 0.0001 key3
        # Bit-switches selected item between 0 and 1
        [[ "$key3" == [CD] ]] && ((selected^=1))
        if [ -z "$key1" ]; then
            (($selected)) && navigate || exit
        fi
        unset key1 key2 key3
    done
}

declare -A tail
# Populating tail array saves on logic when printing
populate
main_menu
