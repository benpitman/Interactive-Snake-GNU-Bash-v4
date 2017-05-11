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
        if (( $ref_row!=$row && $food_row!=$row )) && ! [[ " ${tail_row[@]} " =~ " $row " ]]; then
            echo '|                                     |'
            continue
        fi
        echo -n '|'
        for col in {1..37}; do
            # Print "X" on current position
            if (( $ref_col==$col && $ref_row==$row )); then
                echo -n "o"
                continue
            fi
            if (( $food_col==$col && $food_row==$row )); then
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
    time_taken_s=$(( $( date '+%s' )-$start_time ))
    time_taken=$( printf 'Time Taken: %02dh:%02dm:%02ds' \
            $(( $time_taken_s/3600 )) $(( $time_taken_s%3600/60 )) $(( $time_taken_s%60 )) )
}

add_food() {
    # Populate food position based off snake position
    food_col=$(( $RANDOM%36+1 ))
    until (( $food_col%2==0 && $food_col!=$ref_col )); do
        food_col=$(( $RANDOM%36+1 ))
    done
    food_row=$(( $RANDOM%18+1 ))
    until (( $food_row!=$ref_row )); do
        food_row=$(( $RANDOM%18+1 ))
    done
    [[ "${tail[$food_col,$food_row]}" != " " ]] && add_food
}

navigate() {
    # Save epoch for timer
    [ -z "$start_time" ] && start_time=$( date '+%s' )
    # Current position
    ref_col=20
    ref_row=10
    direction=$(( $RANDOM%4 ))
    tail_len=4
    add_food
    score=0
    stty -echo
    while true; do
        # Add current position to the first tail position
        tail_col+=( $ref_col )
        tail_row+=( $ref_row )
        tail[$ref_col,$ref_row]='x'
        # If the tail reaches the length clear the last from the tail
        if (( ${#tail_col[@]}>$tail_len )); then
            tail[${tail_col[@]:0:1},${tail_row[@]:0:1}]=' '
            tail_col=( ${tail_col[@]:1} )
            tail_row=( ${tail_row[@]:1} )
        fi
        tput reset
        get_time
        show_grid
        pre_time=$( date '+%1N' )
        # Arrow keys are three characters long
        read -sn1 -t 0.$speed key1
        read_pid=$?
        read -sn1 -t 0.0001 key2
        read -sn1 -t 0.0001 key3

        if (( $read_pid!=142 )); then
            post_time=$( date '+%1N' )
            (( $post_time<$pre_time )) && (( post_time+=10 ))
            sleep 0.$(( $speed-($post_time-$pre_time) ))
            read -t 0.0001 -n 10000 discard
        fi

        # Change direction of snake depending on arrow key
        case "$key3" in
           A)   (( $direction!=1 )) && direction=0;; # Up
           B)   (( $direction!=0 )) && direction=1;; # Down
           C)   (( $direction!=3 )) && direction=2;; # Right
           D)   (( $direction!=2 )) && direction=3;; # Left
        esac

        # Increment/Decrement position accoringly
        case "$direction" in
            0)  (( ref_row-- ));;
            1)  (( ref_row++ ));;
            2)  (( ref_col+=2 ));; # Col width is 2 times the size of row
            3)  (( ref_col-=2 ));;
        esac

        # Checks if next move makes the snake head collide with walls or itself
        # TODO
        (( $ref_col==0 || $ref_col==38 )) && exit
        (( $ref_row==0 || $ref_row==19 )) && exit
        [[ "${tail[$ref_col,$ref_row]}" == "x" ]] && exit

        # Checks if next move makes the snake head collide with food
        if (( $food_col==$ref_col && $food_row==$ref_row )); then
            add_food
            (( tail_len++ ))
            (( score+=$increment ))
        fi

        # Checks key pressed for sub menus
        case "$key1" in
            # TODO
            h|p)    pause_time_start=$( date '+%s' )
                    pause
                    pause_time_finish=$( date '+%s' )
                    (( start_time+=$(( $pause_time_finish-$pause_time_start )) ));;
            q)      quit_reset "quit";;
            r)      quit_reset "reset";;
        esac
        unset key1 key2 key3
    done
}

set_difficulty() {
    if [ -z "$*" ]; then
        selected=2
        while true; do
            tput reset
            case $selected in
                4)  VERY_EASY='\e[1;36mVERY  EASY\e[0m'
                    speed=5
                    increment=1
                    unset EASY NORMAL HARD VERY_HARD;;
                3)  EASY='\e[1;36mEASY\e[0m'
                    speed=4
                    increment=2
                    unset VERY_EASY NORMAL HARD VERY_HARD;;
                2)  NORMAL='\e[1;36mNORMAL\e[0m'
                    speed=3
                    increment=3
                    unset VERY_EASY EASY HARD VERY_HARD;;
                1)  HARD='\e[1;36mHARD\e[0m'
                    speed=2
                    increment=4
                    unset VERY_EASY EASY NORMAL VERY_HARD;;
                0)  VERY_HARD='\e[1;36mVERY  HARD\e[0m'
                    speed=1
                    increment=5
                    unset VERY_EASY EASY NORMAL HARD;;
            esac
            set ${VERY_EASY:='VERY  EASY'} \
                ${EASY:='EASY'} \
                ${NORMAL:='NORMAL'} \
                ${HARD:='HARD'} \
                ${VERY_HARD:='VERY  HARD'}
            echo -en "+-------------------------------------+
                    \r|                                     |
                    \r|                                     |
                    \r|          \e[1mChoose Difficulty\e[0m          |
                    \r|                                     |
                    \r|                                     |
                    \r|                                     |
                    \r|                                     |
                    \r|             $VERY_EASY              |
                    \r|                                     |
                    \r|                $EASY                 |
                    \r|                                     |
                    \r|               $NORMAL                |
                    \r|                                     |
                    \r|                $HARD                 |
                    \r|                                     |
                    \r|             $VERY_HARD              |
                    \r|                                     |
                    \r|                                     |
                    \r|                                     |
                    \r+-------------------------------------+"
            read -sn1 key1
            read -sn1 -t 0.0001 key2
            read -sn1 -t 0.0001 key3
            case $key3 in
               A)   (( $selected==4 )) && selected=0 || (( selected++ ));; # Up
               B)   (( $selected==0 )) && selected=4 || (( selected-- ));; # Down
            esac
            [ -z "$key1" ] && break
            unset key1 key2 key3
        done
    else
        speed=$1
    fi
    navigate
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
        [[ "$key3" == [CD] ]] && (( selected^=1 ))
        if [ -z "$key1" ]; then
            (( $selected )) && set_difficulty || exit
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
