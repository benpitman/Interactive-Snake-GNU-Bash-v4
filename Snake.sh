#!/bin/bash

if [ -z "$1" ] || [[ "$1" != "-t" ]]; then
    # Creates a copy of the script to tmp for it to be executed in a new terminal
    sed -n '10,$p' $0 >| /tmp/snake
    gnome-terminal --title "Snake" --geometry 39x21+800+350 -e "bash /tmp/snake" 2>/dev/null
    exit
fi

cleanup() {
    tput clear
    tput cvvis
    stty echo
    rm /tmp/snake 2>/dev/null
}
trap cleanup EXIT

quit_game() {
    clear_map 19
    tput cup 5 14
    echo -e "Are You Sure"
    tput cup 7 11
    echo -e "You Want To Quit?"
    selected=0
    tput civis  # Disable cursor
    while true; do
        case $selected in
            0)  NO='\e[1;36mNO\e[0m'
                YES='YES';;
            1)  YES='\e[1;36mYES\e[0m'
                NO='NO';;
        esac
        tput cup 13 14
        echo -e "$NO      $YES"
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

score_screen() {
    # Draw end-screen menu
    clear_map 19
    tput cup 5 14
    echo -e "You Crashed"
    if (( $score>$high_score )); then
        tput cup 8 12
        echo -e "\e[1mNew High Score!\e[0m"
    fi
    tput cup 11 7
    echo -e "\e[1mWould You Like To Restart?\e[0m"
    selected=0
    tput civis
    while true; do
        case $selected in
            0)  YES='\e[1;36mYES\e[0m'
                NO='NO';;
            1)  NO='\e[1;36mNO\e[0m'
                YES='YES';;
        esac
        tput cup 13 14
        echo -e "$YES      $NO"
        read -sn1 key1
        read -sn1 -t 0.0001 key2
        read -sn1 -t 0.0001 key3
        [[ "$key3" == [CD] ]] && (( selected^=1 ))
        [ -z "$key1" ] && break
        unset key1 key2 key3
    done
    (( $selected )) && exit || new_game
}

pause() {
    # Draw pause splash
    tput cup 9 16
    echo -e "       "
    tput cup 10 16
    echo -e " PAUSE "
    tput cup 11 16
    echo -e "       "
    read -sn1
    tput cup 10 17
    echo -e "     "
}

draw_map() {
    # If tail exists, draw it
    if [ -n "${tail_row[0]}" ]; then
        # If redraw is set, draw full tail with every movement
        if (( $redraw )); then
            for (( link=0; link<${#tail_row[@]}; link++ )); do
                tput cup ${tail_row[$link]} ${tail_col[$link]}
                echo 'x'
            done
        # Else draw only the latest
        else
            tput cup ${tail_row[-1]} ${tail_col[-1]}
            echo 'x'
        fi
    fi
    # Delete last tail link when the full length is visible
    if [ -n "$rem_row" ]; then
        tput cup $rem_row $rem_col
        echo ' '
    fi
    # Draw snake head
    tput cup $ref_row $ref_col
    echo 'o'
    # Draw food
    tput cup $food_row $food_col
    echo '@'
    # Draw stats
    tput cup 20 0
    printf '| %-21s%-15s|' "High Score: $high_score" "Score: $score"
}

add_food() {
    # Populate food position based off snake position
    while true; do
        food_col=$(( $RANDOM%36+1 ))
        (( $food_col&1 )) && continue
        food_row=$(( $RANDOM%18+1 ))
        (( $food_col==$ref_col && $food_row==$ref_row)) && continue
        # Pre-populating Tail array is useful here
        (( ${tail[$food_col,$food_row]} )) && continue
        break
    done
}

navigate() {
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
            if [[ "$key1" == [pPqQ] ]]; then
                [[ "$key1" == [pP] ]] && pause
                [[ "$key1" == [qQ] ]] && quit_game
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
        elif (( $ref_col==0 || $ref_col==38 )) || \
                (( $ref_row==0 || $ref_row==19 )) || \
                (( ${tail[$ref_col,$ref_row]} )); then
            score_screen
        fi

        # Checks if next move makes the snake head collide with food
        if (( $food_col==$ref_col && $food_row==$ref_row )); then
            add_food
            (( tail_len++ ))
            (( score+=$increment ))
            (( $score>$high_score )) && echo "$score" >| $hs_log
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
    (( $1==19 )) && printf '\n| %-21s%-15s|' "High Score: $high_score" "Score: $score"
    tput civis
}

new_game() {
    declare -A tail
    # Populating empty tail array saves on logic when printing
    for y_x in {1..18},{1..37}; do
        tail[$y_x]=0
    done
    # Current position
    ref_col=20
    ref_row=10
    # Tail length and positions
    tail_len=3
    tail_col=()
    tail_row=()
    direction=$(( $RANDOM%4 ))
    score=0
    high_score=$( < $hs_log )
    redraw=0
    add_food
    clear_map 19
    navigate
}

set_difficulty() {
    clear_map 20
    tput cup 3 11
    echo -e "\e[1mChoose Difficulty\e[0m"
    selected=2
    while true; do
        case $selected in
            *)  unset VERY_SLOW SLOW NORMAL FAST VERY_FAST;;&
            4)  VERY_SLOW='\e[1;36mVERY  SLOW\e[0m'
                speed=5
                increment=1;;
            3)  SLOW='\e[1;36mSLOW\e[0m'
                speed=4
                increment=2;;
            2)  NORMAL='\e[1;36mNORMAL\e[0m'
                speed=3
                increment=3;;
            1)  FAST='\e[1;36mFAST\e[0m'
                speed=2
                increment=4;;
            0)  VERY_FAST='\e[1;36mVERY  FAST\e[0m'
                speed=1
                increment=5;;
        esac
        set ${VERY_SLOW:='VERY  SLOW'} \
            ${SLOW:='SLOW'} \
            ${NORMAL:='NORMAL'} \
            ${FAST:='FAST'} \
            ${VERY_FAST:='VERY  FAST'}
        tput cup 8 14
        echo -e "$VERY_SLOW"
        tput cup 10 17
        echo -e "$SLOW"
        tput cup 12 16
        echo -e "$NORMAL"
        tput cup 14 17
        echo -e "$FAST"
        tput cup 16 14
        echo -en "$VERY_FAST"
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
    new_game
}

main_menu() {
    # Clear screen
    tput clear
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
    # Get/Create current high score
    hs_log=/home/$USER/.snake_highscore
    [ -s "$hs_log" ] || echo "0" >| $hs_log
    high_score=$( < $hs_log )
    tput civis  # Disable cursor blinker
    while true; do
        case $selected in
            1)  START='\e[1;36mSTART\e[0m'
                unset QUIT CL_HS;;
            0)  QUIT='\e[1;36mQUIT\e[0m'
                unset CL_HS START;;
            -1) CL_HS='\e[1;36mCLEAR HIGHSCORE\e[0m'
                unset START QUIT;;
        esac
        set ${START:='START'} \
            ${QUIT:='QUIT'} \
            ${CL_HS:='CLEAR HIGHSCORE'}
        # Control posision of the cursor
        tput cup 15 14
        if (( $cheating )); then
            echo -e '\e[1mCHEAT  MODE\e[0m'
        else
            echo -e '           '
        fi
        tput cup 17 12
        echo -e "$START      $QUIT"
        tput cup 19 12
        echo -e "$CL_HS"
        read -sn1 key1
        read -sn1 -t 0.0001 key2
        read -sn1 -t 0.0001 key3
        # Bit-switches selected item between 0 and 1
        [[ "$key3" == [CD] ]] && (( selected^=1 ))
        ( (( $high_score>0 )) && [[ "$key3" == [AB] ]] ) && selected=$(( selected==-1 ? 1 : -1 ))
        [[ "$key2" == O && "$key3" == F ]] && (( cheating^=1 ))
        if [ -z "$key1" ]; then
            if (( $selected==-1 )); then
                echo "0" >| $hs_log
                high_score=0
                selected=1
            elif (( $selected )); then
                set_difficulty
            else
                exit
            fi
        fi
        unset key1 key2 key3
    done
}

stty -echo  #Disable echoing
main_menu
