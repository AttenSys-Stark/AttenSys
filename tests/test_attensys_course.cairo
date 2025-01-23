use starknet::{ContractAddress, contract_address_const, ClassHash};
use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, stop_cheat_caller_address
};

use attendsys::contracts::AttenSysCourse::{
    IAttenSysCourseDispatcher, IAttenSysCourseDispatcherTrait
};

fn deploy_contract(name: ByteArray, hash: ClassHash) -> ContractAddress {
    let contract = declare(name).unwrap();
    let mut constuctor_arg = ArrayTrait::new();
    let contract_owner_address: ContractAddress = contract_address_const::<'admin'>();

    contract_owner_address.serialize(ref constuctor_arg);
    hash.serialize(ref constuctor_arg);

    let (contract_address, _) = contract.deploy(@constuctor_arg).unwrap();

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

    let contract = declare(name).unwrap();
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    (contract_address, contract.class_hash)
}

#[test]
fn test_transfer_admin() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysCourse", hash);

    let admin: ContractAddress = contract_address_const::<'admin'>();
    let new_admin: ContractAddress = contract_address_const::<'new_admin'>();

    let attensys_course_contract = IAttenSysCourseDispatcher { contract_address };

    assert(attensys_course_contract.get_admin() == admin, 'wrong admin');

    start_cheat_caller_address(contract_address, admin);

    attensys_course_contract.transfer_admin(new_admin);
    assert(attensys_course_contract.get_new_admin() == new_admin, 'wrong intended admin');

    stop_cheat_caller_address(contract_address)
}

#[test]
fn test_claim_admin() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysCourse", hash);

    let admin: ContractAddress = contract_address_const::<'admin'>();
    let new_admin: ContractAddress = contract_address_const::<'new_admin'>();

    let attensys_course_contract = IAttenSysCourseDispatcher { contract_address };

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
        'admin claim failed'
    );
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'unauthorized caller')]
fn test_transfer_admin_should_panic_for_wrong_admin() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysCourse", hash);

    let invalid_admin: ContractAddress = contract_address_const::<'invalid_admin'>();
    let new_admin: ContractAddress = contract_address_const::<'new_admin'>();

    let attensys_course_contract = IAttenSysCourseDispatcher { contract_address };

    // Wrong admin transfers admin rights to new_admin: should revert
    start_cheat_caller_address(contract_address, invalid_admin);
    attensys_course_contract.transfer_admin(new_admin);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'unauthorized caller')]
fn test_claim_admin_should_panic_for_wrong_new_admin() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysCourse", hash);

    let admin: ContractAddress = contract_address_const::<'admin'>();
    let new_admin: ContractAddress = contract_address_const::<'new_admin'>();
    let wrong_new_admin: ContractAddress = contract_address_const::<'wrong_new_admin'>();

    let attensys_course_contract = IAttenSysCourseDispatcher { contract_address };

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
