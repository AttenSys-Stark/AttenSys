use attendsys::contracts::sponsor::AttenSysSponsor::{
    IAttenSysSponsorDispatcher, IAttenSysSponsorDispatcherTrait, IERC20Dispatcher,
    IERC20DispatcherTrait,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_block_timestamp_global, start_cheat_caller_address, stop_cheat_caller_address,
    test_address,
};
use starknet::{ClassHash, ContractAddress, contract_address_const, get_caller_address};

fn deploy(token: bool) -> (ContractAddress, ContractAddress) {
    let org_address: ContractAddress = contract_address_const::<'contract_owner_address'>();
    let event_address: ContractAddress = contract_address_const::<'contract_event_address'>();

    if (token) {
        let mut token_constructor_arg = ArrayTrait::new();
        org_address.serialize(ref token_constructor_arg);
        let token_contract = declare("AttenSysToken").unwrap().contract_class();
        let (token_contract_address, _) = ContractClassTrait::deploy(
            token_contract, @token_constructor_arg,
        )
            .unwrap();
        (token_contract_address, org_address)
    } else {
        let mut constructor_arg = ArrayTrait::new();
        org_address.serialize(ref constructor_arg);
        event_address.serialize(ref constructor_arg);
        let sponsor_contract = declare("AttenSysSponsor").unwrap().contract_class();
        let (sponsor_contract_address, _) = ContractClassTrait::deploy(
            sponsor_contract, @constructor_arg,
        )
            .unwrap();
        (sponsor_contract_address, org_address)
    }
}

fn deposit(
    token_contract_address: ContractAddress,
    sponsor_contract_address: ContractAddress,
    caller: ContractAddress,
) {
    // set up the dispatcher for token contract
    //  address has to give approval to the sponsorship contract to spend his token
    let token_contract_dispatcher = IERC20Dispatcher { contract_address: token_contract_address };

    // interact with token contract
    start_cheat_caller_address(token_contract_address, caller);
    token_contract_dispatcher.approve(sponsor_contract_address, 20000);
    stop_cheat_caller_address(token_contract_address);

    // set up the dispatcher for sponsor contract
    //  call the deposit function from the sponsor
    let sponsor_dispatcher = IAttenSysSponsorDispatcher {
        contract_address: sponsor_contract_address,
    };

    // interact with sponsor contract
    start_cheat_caller_address(sponsor_contract_address, caller);
    let sponsor_dispatcher = IAttenSysSponsorDispatcher {
        contract_address: sponsor_contract_address,
    };
    sponsor_dispatcher.deposit(caller, token_contract_address, 20000);
    stop_cheat_caller_address(sponsor_contract_address);

    assert(token_contract_dispatcher.balanceOf(caller) == 0, 'Deposit successful');
    assert(
        token_contract_dispatcher.balanceOf(sponsor_contract_address) == 20000,
        'Sponsorship updated',
    );
}

fn withdraw(
    token_contract_address: ContractAddress,
    sponsor_contract_address: ContractAddress,
    caller: ContractAddress,
) {
    // set up the dispatcher for token contract
    let token_contract_dispatcher = IERC20Dispatcher { contract_address: token_contract_address };

    // setup dispatcher for sponsor
    let sponsor_dispatcher = IAttenSysSponsorDispatcher {
        contract_address: sponsor_contract_address,
    };

    // test for withdrawal from the sponsorship contract
    start_cheat_caller_address(sponsor_contract_address, caller);
    sponsor_dispatcher.withdraw(token_contract_address, 20000);
    stop_cheat_caller_address(sponsor_contract_address);

    assert(token_contract_dispatcher.balanceOf(caller) == 20000, 'Deposit successful');
    assert(
        token_contract_dispatcher.balanceOf(sponsor_contract_address) == 0, 'Sponsorship updated',
    );
}

#[test]
fn test_deposit() {
    let (token_contract, caller) = deploy(true);
    let (sponsor_contract, _caller) = deploy(false);

    deposit(token_contract, sponsor_contract, caller);
}

#[test]
fn test_withdraw() {
    let (token_contract, caller) = deploy(true);
    let (sponsor_contract, _caller) = deploy(false);
    deposit(token_contract, sponsor_contract, caller);
    withdraw(token_contract, sponsor_contract, caller);
}

#[test]
#[should_panic(expected: "Not enough balance")]
fn should_panic_no_fund() {
    panic!("Not enough balance");
    let (token_contract, caller) = deploy(true);
    let (sponsor_contract, _caller) = deploy(false);

    // withdrawing without a deposit should revert
    withdraw(token_contract, sponsor_contract, caller);
}

