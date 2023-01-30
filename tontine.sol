// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Tontine {

    struct Round {
        address payable round_payee;
        uint8 round_rank;
        address payable[] deposits_by;
        // todo: add date constraint
    }

    address creator;
    address payable[] registrants;
    Round[] rounds;
    uint round_pointer = 0;
    uint8 payout_amount;
    uint num_members;
    uint8 deposit_amount;

    // todo: add events

    // modifiers

    /// make sure that we choose a valid rank and that the position is not taken
    modifier valid_rank(uint payout_rank) {
        require(1 <= payout_rank && payout_rank <= num_members, "Rank is out of range");
        require(rounds[payout_rank - 1].round_payee == payable(0x0000000000000000000000000000000000000000), "Rank is taken");
        _;
    }

    modifier registration_open() {
        // registration is open as long as payee spots are vacants
        bool open = false;
        for (uint i=0; i<rounds.length; i++) {
            if (rounds[i].round_payee == payable(0x0000000000000000000000000000000000000000)) {
                open = true;
            }
        }
        require(open, "The registration is closed");
        _;
    }

    modifier tontine_not_finished() {
        require(round_pointer < num_members, "The tontine is finished");
        _;
    }

    modifier exact_deposit_amount(uint256 amount) {
        require(amount == 1 ether * deposit_amount, "The amount must be equal to the deposit value");
        _;
    }

    modifier no_deposit_for_round() {
        bool no_deposit_in_round = true;
        for (uint i=0; i<rounds[round_pointer].deposits_by.length; i++) {
            if (rounds[round_pointer].deposits_by[i] == payable(msg.sender)) {
                no_deposit_in_round = false;
            }
        }
        require(no_deposit_in_round, "A deposit was already made from this address and this round");
        _;
    }

    /// create a new tontine with a number of rounds and a payout amount
    constructor(uint8 numMembers, uint8 payout, uint8 choosen_rank)  {
        creator = msg.sender;
        payout_amount = payout;
        num_members = numMembers;
        deposit_amount = payout/numMembers;

        // initialize the rounds
        for (uint i=0; i<num_members; i++) {
            rounds.push(
                Round(
                    payable(0x0000000000000000000000000000000000000000),
                    0,
                    new address payable[](0)
                )
            );
        }

        // register creator
        register(choosen_rank);
    }

    /// subscribe to tontine
    function register(uint8 payout_rank) public registration_open() valid_rank(payout_rank) {

        // update the rounds
        rounds[payout_rank - 1].round_payee = payable(msg.sender);
        rounds[payout_rank - 1].round_rank = payout_rank;

        // add registrant in the list
        registrants.push(payable(msg.sender));
    }

    /// payout subscriber with current rank
    function payout_subscriber() private tontine_not_finished() {

        // transfer the total amount to  the right subscriber
        address payable addr = rounds[round_pointer].round_payee;
        addr.transfer(address(this).balance);

        // update the pointer (that also terminate the tontine)
        round_pointer += 1;
    }

    /// pay deposit for each round
    function deposit() public payable exact_deposit_amount(msg.value) no_deposit_for_round() {


        // register the deposit
        rounds[round_pointer].deposits_by.push(payable(msg.sender));

        // make the payout if all subscription have been paid for this round
        if (rounds[round_pointer].deposits_by.length == num_members) {
            payout_subscriber();
        }

    }

    /// getters
    function get_current_round() public view returns (Round memory) {
        return rounds[round_pointer];
    }

    function get_registered_members() public view returns (uint256) {
        return registrants.length;
    }

    function get_total_spots() public view returns (uint256) {
        return num_members;
    }

    function get_payout() public view returns (uint8) {
        return payout_amount;
    }

    function get_deposit_amount() public view returns (uint8) {
        return deposit_amount;
    }
}
