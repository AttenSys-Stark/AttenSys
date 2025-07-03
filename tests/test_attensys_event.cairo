use attendsys::contracts::event::AttenSysEvent::{
    IAttenSysEventDispatcher, IAttenSysEventDispatcherTrait,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address, test_address,
};
use starknet::{ClassHash, ContractAddress, contract_address_const};

fn deploy_contract(name: ByteArray, hash: ClassHash) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let mut constuctor_arg = ArrayTrait::new();
    let contract_owner_address: ContractAddress = contract_address_const::<'admin'>();

    contract_owner_address.serialize(ref constuctor_arg);
    hash.serialize(ref constuctor_arg);

    let (contract_address, _) = ContractClassTrait::deploy(contract, @constuctor_arg).unwrap();

    contract_address
}

fn deploy_nft_contract(name: ByteArray) -> (ContractAddress, ClassHash) {
    let token_uri: ByteArray = "https://dummy_uri.com/your_id";
    let name_: ByteArray = "Attensys";
    let symbol: ByteArray = "ATS";

    let mut constructor_calldata = ArrayTrait::new();

    token_uri.serialize(ref constructor_calldata);
    name_.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);

    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = ContractClassTrait::deploy(contract, @constructor_calldata)
        .unwrap();

    (contract_address, *contract.class_hash)
}

fn deploy_event_contract(
    name: ByteArray,
    hash: ClassHash,
    _token_address: ContractAddress,
    sponsor_contract_address: ContractAddress,
) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();

    let mut constuctor_arg = ArrayTrait::new();
    let contract_owner_address: ContractAddress = contract_address_const::<'admin'>();

    contract_owner_address.serialize(ref constuctor_arg);
    hash.serialize(ref constuctor_arg);
    _token_address.serialize(ref constuctor_arg);
    sponsor_contract_address.serialize(ref constuctor_arg);

    let (contract_address, _) = ContractClassTrait::deploy(contract, @constuctor_arg).unwrap();

    contract_address
}

#[test]
fn test_transfer_admin() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    // mock event with test addresses
    let contract_address = deploy_event_contract(
        "AttenSysEvent", hash, test_address(), test_address(),
    );

    let admin: ContractAddress = contract_address_const::<'admin'>();
    let new_admin: ContractAddress = contract_address_const::<'new_admin'>();

    let attensys_event_contract = IAttenSysEventDispatcher { contract_address };

    assert(attensys_event_contract.get_admin() == admin, 'wrong admin');

    start_cheat_caller_address(contract_address, admin);

    attensys_event_contract.transfer_admin(new_admin);
    assert(attensys_event_contract.get_new_admin() == new_admin, 'wrong intended admin');

    stop_cheat_caller_address(contract_address)
}

#[test]
fn test_claim_admin() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    // mock event with test addresses
    let contract_address = deploy_event_contract(
        "AttenSysEvent", hash, test_address(), test_address(),
    );

    let admin: ContractAddress = contract_address_const::<'admin'>();
    let new_admin: ContractAddress = contract_address_const::<'new_admin'>();

    let attensys_course_contract = IAttenSysEventDispatcher { contract_address };

    assert(attensys_course_contract.get_admin() == admin, 'wrong admin');

    // Admin transfers admin rights to new_admin
    start_cheat_caller_address(contract_address, admin);
    attensys_course_contract.transfer_admin(new_admin);
    assert(attensys_course_contract.get_new_admin() == new_admin, 'wrong intended admin');
    stop_cheat_caller_address(contract_address);

    // New admin claims admin rights
    start_cheat_caller_address(contract_address, new_admin);
    attensys_course_contract.claim_admin_ownership();
    assert(attensys_course_contract.get_admin() == new_admin, 'admin claim failed');
    assert(
        attensys_course_contract.get_new_admin() == contract_address_const::<0>(),
        'admin claim failed',
    );
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'unauthorized caller')]
fn test_transfer_admin_should_panic_for_wrong_admin() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    // mock event with test addresses
    let contract_address = deploy_event_contract(
        "AttenSysEvent", hash, test_address(), test_address(),
    );

    let invalid_admin: ContractAddress = contract_address_const::<'invalid_admin'>();
    let new_admin: ContractAddress = contract_address_const::<'new_admin'>();

    let attensys_course_contract = IAttenSysEventDispatcher { contract_address };

    // Wrong admin transfers admin rights to new_admin: should revert
    start_cheat_caller_address(contract_address, invalid_admin);
    attensys_course_contract.transfer_admin(new_admin);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'unauthorized caller')]
fn test_claim_admin_should_panic_for_wrong_new_admin() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    // mock event with test addresses
    let contract_address = deploy_event_contract(
        "AttenSysEvent", hash, test_address(), test_address(),
    );

    let admin: ContractAddress = contract_address_const::<'admin'>();
    let new_admin: ContractAddress = contract_address_const::<'new_admin'>();
    let wrong_new_admin: ContractAddress = contract_address_const::<'wrong_new_admin'>();

    let attensys_course_contract = IAttenSysEventDispatcher { contract_address };

    assert(attensys_course_contract.get_admin() == admin, 'wrong admin');

    // Admin transfers admin rights to new_admin
    start_cheat_caller_address(contract_address, admin);
    attensys_course_contract.transfer_admin(new_admin);
    stop_cheat_caller_address(contract_address);

    // Wrong new admin claims admin rights: should panic
    start_cheat_caller_address(contract_address, wrong_new_admin);
    attensys_course_contract.claim_admin_ownership();
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_toggle_event_status() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    // mock event with test addresses
    let contract_address = deploy_event_contract(
        "AttenSysEvent", hash, test_address(), test_address(),
    );

    let admin: ContractAddress = contract_address_const::<'admin'>();
    let attensys_event_contract = IAttenSysEventDispatcher { contract_address };

    assert(attensys_event_contract.get_admin() == admin, 'wrong admin');

    start_cheat_caller_address(contract_address, admin);

    attensys_event_contract
        .create_event(
            test_address(),
            "test_event",
            "https://dummy_uri.com/your_id",
            "Attensys",
            "ATS",
            1000,
            2000,
            1,
            "https://dummy_event_uri.com/your_id",
            0,
        );

    let event_details = attensys_event_contract.get_event_details(1);
    assert(event_details.is_suspended == false, 'event is suspended');
    assert(attensys_event_contract.get_event_suspended_status(1) == false, 'event is suspended');

    attensys_event_contract.toggle_event_suspended_status(1, true);
    let event_details = attensys_event_contract.get_event_details(1);
    assert(event_details.is_suspended == true, 'event is not suspended');
    assert(attensys_event_contract.get_event_suspended_status(1) == true, 'event is not suspended');

    attensys_event_contract.toggle_event_suspended_status(1, false);
    let event_details = attensys_event_contract.get_event_details(1);
    assert(event_details.is_suspended == false, 'event is suspended');
    assert(attensys_event_contract.get_event_suspended_status(1) == false, 'event is suspended');

    stop_cheat_caller_address(contract_address)
}

#[test]
#[should_panic(expected: 'unauthorized caller')]
fn test_toggle_event_should_panic_for_wrong_admin() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    // mock event with test addresses
    let contract_address = deploy_event_contract(
        "AttenSysEvent", hash, test_address(), test_address(),
    );

    let other_admin: ContractAddress = contract_address_const::<'other_admin'>();
    let attensys_event_contract = IAttenSysEventDispatcher { contract_address };

    start_cheat_caller_address(contract_address, other_admin);

    attensys_event_contract
        .create_event(
            test_address(),
            "test_event",
            "https://dummy_uri.com/your_id",
            "Attensys",
            "ATS",
            1000,
            2000,
            1,
            "https://dummy_event_uri.com/your_id",
            0,
        );

    let event_details = attensys_event_contract.get_event_details(1);
    assert(event_details.is_suspended == false, 'event is suspended');

    attensys_event_contract.toggle_event_suspended_status(1, true);
    let event_details = attensys_event_contract.get_event_details(1);
    assert(event_details.is_suspended == true, 'event is not suspended');

    stop_cheat_caller_address(contract_address)
}
