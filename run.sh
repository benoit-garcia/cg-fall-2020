#!/bin/bash

# Remove before submitting
debug=0

# global variables
known_casts=()
orders=()
order=""
requirements=()
missing_items=()

action="WAIT"

# Debugging tools
catd () {
    if [[ ${debug} -eq 1 ]]; then
        cat "$@" >&2
    fi
}

echod () {
    if [[ ${debug} -eq 1 ]]; then
        echo "$@" >&2
    fi
}

get_actions() {
    known_casts=()
    orders=()

    read -r actionCount
    for (( i=0; i<actionCount; i++ )); do
        read -r actionId actionType delta0 delta1 delta2 delta3 price tomeIndex taxCount castable repeatable
        # actionId: the unique ID of this spell or recipe
        # actionType: in the first league: BREW; later: CAST, OPPONENT_CAST, LEARN, BREW
        # delta0: tier-0 ingredient change
        # delta1: tier-1 ingredient change
        # delta2: tier-2 ingredient change
        # delta3: tier-3 ingredient change
        # price: the price in rupees if this is a potion
        # tomeIndex: in the first two leagues: always 0; later: the index in the tome if this is a tome spell, equal to the read-ahead tax; For brews, this is the value of the current urgency bonus
        # taxCount: in the first two leagues: always 0; later: the amount of taxed tier-0 ingredients you gain from learning this spell; For brews, this is how many times you can still gain an urgency bonus
        # castable: in the first league: always 0; later: 1 if this is a castable player spell
        # repeatable: for the first two leagues: always 0; later: 1 if this is a repeatable player spell
        case $actionType in
            BREW)
                orders+=("${actionId}	${actionType}	${delta0}	${delta1}	${delta2}	${delta3}	${price}	${tomeIndex}	${taxCount}	${castable}	${repeatable}")
                ;;
            CAST)
                known_casts+=("${actionId}	${actionType}	${delta0}	${delta1}	${delta2}	${delta3}	${price}	${tomeIndex}	${taxCount}	${castable}	${repeatable}")
                ;;
            *)
                # Don't care
                ;;
        esac
    done
}

get_inventories() {
    read -ra my_inventory
# shellcheck disable=SC2034 # Don't care about my opponent's inventory!
    read -r opponent_inventory
}

get_missing_items() {
    missing_items=()
    missing_items+=($((requirements[0]+my_inventory[0])))
    missing_items+=($((requirements[1]+my_inventory[1])))
    missing_items+=($((requirements[2]+my_inventory[2])))
    missing_items+=($((requirements[3]+my_inventory[3])))
}

get_order() {
    # Less profitable
    order="$(printf '%s\n' "${orders[@]}" | sort -k 7 -n -r | tail -1)"
    # Most profitable
#    order="$(printf '%s\n' "${orders[@]}" | sort -k 7 -n -r | head -1)"
}

get_requirements() {
    read -ra requirements <<< "$(printf '%s' "$order" | cut -f 3,4,5,6)"
}

display_known_casts() {
    echod "Known casts:"
    for ((i=0;i<${#known_casts[*]};i++)); do
        echod -e "\t${known_casts[$i]}"
    done
    echod
}

display_inventory() {
    echod -e "My Inventory:"
    for ((i=0;i<${#my_inventory[*]};i++)); do
        echod -e "\t${my_inventory[$i]}"
    done
    echod
}

display_missing_items() {
    echod "Missing items:"
    echod -e "\tBlue:\t${missing_items[0]}"
    echod -e "\tGreen:\t${missing_items[1]}"
    echod -e "\tOrange:\t${missing_items[2]}"
    echod -e "\tYellow:\t${missing_items[3]}"
    echod
}

display_order() {
    echod -e "Most profitable orders:\n\t${order}"
    echod
}

display_orders() {
    echod "Current orders:"
    for ((i=0;i<${#orders[*]};i++)) do
        echod -e "\t${orders[$i]}"
    done
    echod
}

display_requirements() {
    echod "Requirements:"
    for ((i=0;i<${#requirements[*]};i++)) do
        echod -e "\t${requirements[$i]}"
    done
    echod
}

cast() {
    local req_item
    local dep_item

    req_item=${1}
    dep_item=$(($1-1))

    if [[ ${missing_items[$req_item]} -lt 0 ]]; then
        echod "need item $req_item"
        if [[ $(printf '%s' "${known_casts[$req_item]}" | cut -f 10) -eq 0 ]]; then
            echod "Can cast item ${req_item}. Will rest."
            action="REST"
        else
            if [[ (${my_inventory[$dep_item]} -le 0) && (${req_item} -gt 0) ]]; then
                echod "Can't cast item ${req_item}. Will cast dependency."
                missing_items[$dep_item]=$((${missing_items[$dep_item]}-1))
                cast ${dep_item}
            else
                action=$(printf '%s' "${known_casts[$req_item]}" | awk '{print $2 " " $1}')
            fi
        fi
    else
        if [[ $req_item -gt 0 ]]; then
            echod "Don't need item $req_item; skipping to ${dep_item}"
            cast ${dep_item}
        else
            echod "Dont need item ${req_item} (blue)"
            action=$(printf '%s' "${order}" | awk '{print $2 " " $1}')
        fi
    fi
}

while true; do
    action="WAIT"
    get_actions
    get_inventories
    get_order
    get_requirements
    get_missing_items

    display_orders
    display_known_casts
    display_order
    display_inventory
    display_requirements
    display_missing_items

    cast 3
    echo "${action}"
done