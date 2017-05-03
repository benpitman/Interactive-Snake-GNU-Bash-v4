#!/bin/bash

# Creates a copy of the script to tmp for it to be executed in a new terminal
sed -n '8,$p' $0 >| /tmp/snake
gnome-terminal --title "Snake" --geometry 39x21+800+350 -e 'bash /tmp/snake' 2>/dev/null
exit

extrap() {
    rm /tmp/snake
}

show_grid() {
    printf '%-28s%s\n' "$time_taken" "Score: $score"
    echo -e '+-------------------------------------+'
    for row in {1..18}; do
        # If snake is not on this row, print an empty row to save time
        if (($ref_row!=$row && $food_row!=$row)) && ! [[ " ${tail_row[@]} " =~ " $row " ]]; then
            echo '|                                     |'
            continue
        fi
        echo -n '|'
        for col in {1..37}; do
            # Print "X" on current position
            if (($ref_col==$col && $ref_row==$row)); then
                echo -n "o"
                continue
            fi
            if (($food_col==$col && $food_row==$row)); then
                echo -n "@"
                continue
            fi
            # Print "x" or " " depending on tail position
            echo -n "${tail[$col,$row]}"
        done
        echo '|'
    done
    echo -n '+-------------------------------------+'
}

get_time() {
    # Calculate current time taken
    time_taken_s=$(($(date '+%s')-$start_time))
    time_taken=$(printf 'Time Taken: %02dh:%02dm:%02ds' \
            $(($time_taken_s/3600)) $(($time_taken_s%3600/60)) $(($time_taken_s%60)))
}

add_food() {
    # Populate food position based off snake position
    while true; do
        food_col=$(($RANDOM%36+1))
        (($food_col%2)) && continue
        (($food_col==$ref_col)) && continue
        food_row=$(($RANDOM%18+1))
        (($food_row==$ref_row)) && continue
        [[ "${tail[$food_col,$food_row]}" != " " ]] && continue
        break
    done
}

navigate() {
    # Save epoch for timer
    [ -z "$start_time" ] && start_time=$(date '+%s')
    # Current position
    ref_col=20
    ref_row=10
    speed=9 # Decrememnt at tail length 6 9 13 18 24 31 39 48
    direction=$(($RANDOM%4))
    tail_len=4
    tail_col=()
    tail_row=()
    add_food
    score=0
    stty -echo
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
        get_time
        show_grid
        pre_time=$(date '+%1N')
        # Arrow keys are three characters long
        read -sn1 -t 0.$speed key1
        read_pid=$?
        # Refresh the screen every second to update timer
        read -sn1 -t 0.0001 key2
        read -sn1 -t 0.0001 key3

        # BUG double spacing
        if (($read_pid==142)); then
            post_time=$(date '+%1N')
            (($post_time<$pre_time)) && (($post_time+10))
            time_taken_n=$(($post_time-$pre_time))
            (($time_taken_n<$speed)) && sleep 0.$(($speed-$time_taken_n))
            read -t 0.0001 -n 10000 discard
        fi

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

        # Checks if next move makes the snake head collide with walls or itself
        # TODO
        (($ref_col==0 || $ref_col==38)) && exit
        (($ref_row==0 || $ref_row==19)) && exit
        [[ "${tail[$ref_col,$ref_row]}" == "x" ]] && exit

        # Checks if next move makes the snake head collide with food
        if (($food_col==$ref_col && $food_row==$ref_row)); then
            add_food
            ((tail_len++))
            [[ $tail_len =~ ^(6|9|13|18|24|31|39|48)$ ]] && ((speed--))
            ((score++))
        fi

        # Checks key pressed for sub menus
        case "$key1" in
            # TODO
            h|p)    pause_time_start=$(date '+%s')
                    pause
                    pause_time_finish=$(date '+%s')
                    ((start_time+=$(($pause_time_finish-$pause_time_start))));;
            q)      quit_reset "quit";;
            r)      quit_reset "reset";;
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
            \r|                                     |
            \r$(show_help)
            \r|                                     |
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

populate() {
    for row in {1..18}; do
        for col in {1..37}; do
            tail[$col,$row]=" "
        done
    done
}

declare -A tail
# Populating empty tail array saves on logic when printing
populate
main_menu
