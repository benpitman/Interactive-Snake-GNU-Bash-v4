#!/bin/bash

if [ -z "$1" ] || [[ "$1" != "-t" ]]; then
    # Creates a copy of the script to tmp for it to be executed in a new terminal
    sed -n '10,$p' $0 >| /tmp/snake
    gnome-terminal --title "Snake" --geometry 39x21+800+350 -e 'bash /tmp/snake' 2>/dev/null
    exit
fi

cleanup() {
    rm /tmp/snake 2>/dev/null
    tput cvvis
    stty echo
}
trap cleanup EXIT

quit_game() {
    clear_map 19
    printf '\n%-28s%s' "$time_taken" "Score: $score"
    tput cup 5 26
    echo -e "\b\b\b\b\b\b\b\b\b\b\b\b\e[1mAre You Sure\e[0m"
    tput cup 7 28
    echo -e "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\e[1mYou Want To Quit?\e[0m"
    selected=0
    tput civis  # Disable cursor
    while true; do
        case $selected in
            0)  NO='\e[1;36mNO\e[0m'
                YES='YES';;
            1)  YES='\e[1;36mYES\e[0m'
                NO='NO';;
        esac
        tput cup 13 25
        echo -e "\b\b\b\b\b\b\b\b\b\b\b$NO      $YES"
        read -sn1 key1
        read -sn1 -t 0.0001 key2
        read -sn1 -t 0.0001 key3
        [[ "$key3" == [CD] ]] && (( selected^=1 ))
        [ -z "$key1" ] && break
        unset key1 key2 key3
    done
    (( $selected )) && exit
    clear_map 19
}

pause() {
    # Draw pause splash
    tput cup 9 23
    echo -e "\b\b\b\b\b\b\b       "
    tput cup 10 23
    echo -e "\b\b\b\b\b\b\b PAUSE "
    tput cup 11 23
    echo -e "\b\b\b\b\b\b\b       "
    read -sn1
    tput cup 10 23
    echo -e "\b\b\b\b\b\b\b       "
}

draw_map() {
    # If tail exists, draw it
    if [ -n "${tail_row[0]}" ]; then
        # If redraw is set, draw full tail with every movement
        if (( $redraw )); then
            for (( link=0; link<${#tail_row[@]}; link++ )); do
                tput cup ${tail_row[$link]} $(( ${tail_col[$link]}+1 ))
                echo -e '\bx'
            done
        # Else draw only the latest
        else
            tput cup ${tail_row[-1]} $(( ${tail_col[-1]}+1 ))
            echo -e '\bx'
        fi
    fi
    # Delete last tail link when the full length is visible
    if [ -n "$rem_row" ]; then
        tput cup $rem_row $(( $rem_col+1 ))
        echo -e '\b '
    fi
    # Draw snake head
    tput cup $ref_row $(( $ref_col+1 ))
    echo -e '\bo'
    # Draw food
    tput cup $food_row $(( $food_col+1 ))
    echo -e '\b@'

    # Calculate current time taken
    time_taken_s=$(( $( date '+%s' )-$start_time ))
    time_taken=$( printf 'Time Taken: %02dh:%02dm:%02ds' \
            $(( $time_taken_s/3600 )) $(( $time_taken_s%3600/60 )) $(( $time_taken_s%60 )) )
    tput cup 21 0
    printf '%-28s%s' "$time_taken" "Score: $score"
}

add_food() {
    # Populate food position based off snake position
    while true; do
        food_col=$(( $RANDOM%36+1 ))
        (( $food_col&1 )) && continue
        food_row=$(( $RANDOM%18+1 ))
        (( $food_col==$ref_col && $food_row==$ref_row)) && continue
        (( ${tail[$food_col,$food_row]} )) && continue
        break
    done
}

navigate() {
    # Save epoch for timer
    [ -z "$start_time" ] && start_time=$( date '+%s' )
    # Current position
    ref_col=20
    ref_row=10
    tail_len=3
    direction=$(( $RANDOM%4 ))
    score=0
    redraw=0
    add_food
    clear_map 19
    while true; do
        draw_map
        redraw=$cheating
        pre_time=$( date '+%1N' )
        # Arrow keys are three characters long
        read -sn1 -t 0.$speed key1
        read_pid=$?
        read -sn1 -t 0.0001 key2
        read -sn1 -t 0.0001 key3

        if (( $read_pid!=142 )); then
            # Checks key pressed for sub menus
            if [[ "$key1" == [pq] ]]; then
                pause_time_start=$( date '+%s' )
                [[ "$key1" == p ]] && pause
                [[ "$key1" == q ]] && quit_game
                pause_time_finish=$( date '+%s' )
                (( start_time+=$(( $pause_time_finish-$pause_time_start )) ))
                redraw=1
                continue
            fi
            # Put a delay on key presses to prevent spamming
            post_time=$( date '+%1N' )
            (( $post_time<$pre_time )) && (( post_time+=10 ))
            sleep 0.$(( $speed-($post_time-$pre_time) ))
            # Clear input buffer
            read -t 0.0001 -n 10000 discard
        fi

        # Add current position to the first tail position
        tail_col+=( $ref_col )
        tail_row+=( $ref_row )
        tail[$ref_col,$ref_row]=1
        # If the tail reaches the length clear the last from the tail
        if (( ${#tail_col[@]}>$tail_len )); then
            rem_col=${tail_col[@]:0:1}
            rem_row=${tail_row[@]:0:1}
            tail[${tail_col[@]:0:1},${tail_row[@]:0:1}]=0
            tail_col=( ${tail_col[@]:1} )
            tail_row=( ${tail_row[@]:1} )
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
        if (( $cheating )); then
            (( $ref_col==0 )) && ref_col=36
            (( $ref_col==38 )) && ref_col=2
            (( $ref_row==0 )) && ref_row=18
            (( $ref_row==19 )) && ref_row=1
        else
            (( $ref_col==0 || $ref_col==38 )) && exit
            (( $ref_row==0 || $ref_row==19 )) && exit
            (( ${tail[$ref_col,$ref_row]} )) && exit
        fi

        # Checks if next move makes the snake head collide with food
        if (( $food_col==$ref_col && $food_row==$ref_row )); then
            add_food
            (( tail_len++ ))
            (( score+=$increment ))
        fi

        unset key1 key2 key3
    done
}

clear_map() {
    # Render blank map
    tput reset
    echo -e '+-------------------------------------+'
    for (( b=1; b<$1; b++ )); do
        echo '|                                     |'
    done
    echo -en '+-------------------------------------+'
    tput civis
}

set_difficulty() {
    clear_map 20
    tput cup 3 28
    echo -e "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\e[1mChoose Difficulty\e[0m"
    selected=2
    while true; do
        case $selected in
            4)  VERY_SLOW='\e[1;36mVERY  SLOW\e[0m'
                speed=5
                increment=1
                unset SLOW NORMAL FAST VERY_FAST;;
            3)  SLOW='\e[1;36mSLOW\e[0m'
                speed=4
                increment=2
                unset VERY_SLOW NORMAL FAST VERY_FAST;;
            2)  NORMAL='\e[1;36mNORMAL\e[0m'
                speed=3
                increment=3
                unset VERY_SLOW SLOW FAST VERY_FAST;;
            1)  FAST='\e[1;36mFAST\e[0m'
                speed=2
                increment=4
                unset VERY_SLOW SLOW NORMAL VERY_FAST;;
            0)  VERY_FAST='\e[1;36mVERY  FAST\e[0m'
                speed=1
                increment=5
                unset VERY_SLOW SLOW NORMAL FAST;;
        esac
        set ${VERY_SLOW:='VERY  SLOW'} \
            ${SLOW:='SLOW'} \
            ${NORMAL:='NORMAL'} \
            ${FAST:='FAST'} \
            ${VERY_FAST:='VERY  FAST'}
        tput cup 8 24
        echo -e "\b\b\b\b\b\b\b\b\b\b$VERY_SLOW"
        tput cup 10 22
        echo -e "\b\b\b\b\b$SLOW"
        tput cup 12 23
        echo -e "\b\b\b\b\b\b\b$NORMAL"
        tput cup 14 22
        echo -e "\b\b\b\b\b$FAST"
        tput cup 16 24
        echo -en "\b\b\b\b\b\b\b\b\b\b$VERY_FAST"
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
    (( $cheating )) && increment=0
    navigate
}

main_menu() {
    # Display the main menu
    echo -en "+-------------------------------------+
        \r|                                     |
        \r|            Ben  Pitman's            |
        \r|                                     |
        \r|              \e[1mS N A K E\e[0m              |
        \r|                                     |
        \r|                                     |
        \r|                                     |
        \r|               \e[1mCONTROLS\e[0m              |
        \r|                                     |
        \r|    Arrow Keys    -    Move          |
        \r|        P         -    Pause         |
        \r|   Q or Ctrl-C    -    Quit          |
        \r|                                     |
        \r|                                     |
        \r|                                     |
        \r|                                     |
        \r|                                     |
        \r|                                     |
        \r|                                     |
        \r+-------------------------------------+"
    selected=1
    cheating=0
    tput civis  # Disable cursor blinker
    while true; do
        case $selected in
            1)  START='\e[1;36mSTART\e[0m'
                QUIT='QUIT';;
            0)  START='START'
                QUIT='\e[1;36mQUIT\e[0m';;
        esac
        # Control posision of the cursor
        tput cup 16 25
        if (( $cheating )); then
            echo -e '\b\b\b\b\b\b\b\b\b\b\b\e[1mCHEAT  MODE\e[0m'
        else
            echo -e '\b\b\b\b\b\b\b\b\b\b\b           '
        fi
        tput cup 18 27
        echo -e "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b$START      $QUIT"
        read -sn1 key1
        read -sn1 -t 0.0001 key2
        read -sn1 -t 0.0001 key3
        # Bit-switches selected item between 0 and 1
        [[ "$key3" == [CD] ]] && (( selected^=1 ))
        [[ "$key2" == O && "$key3" == F ]] && (( cheating^=1 ))
        if [ -z "$key1" ]; then
            (( $selected )) && set_difficulty || exit
        fi
        unset key1 key2 key3
    done
}

populate() {
    for row in {1..18}; do
        for col in {1..37}; do
            tail[$col,$row]=0
        done
    done
}

stty -echo  #Disable echoing
declare -A tail
# Populating empty tail array saves on logic when printing
populate
main_menu
