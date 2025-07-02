use attendsys::contracts::course::AttenSysCourse;
use attendsys::contracts::course::AttenSysCourse::{
    IAttenSysCourseDispatcher, IAttenSysCourseDispatcherTrait,
};
use attendsys::contracts::event::AttenSysEvent::{
    IAttenSysEventDispatcher, IAttenSysEventDispatcherTrait,
};
use attendsys::contracts::org::AttenSysOrg::{IAttenSysOrgDispatcher, IAttenSysOrgDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address, test_address,
};
use starknet::{ClassHash, ContractAddress, contract_address_const};


fn deploy_contract(name: ByteArray, hash: ClassHash) -> (ContractAddress, ClassHash) {
    let contract = declare(name).unwrap().contract_class();
    let mut constuctor_arg = ArrayTrait::new();
    let contract_owner_address: ContractAddress = contract_address_const::<'admin'>();

    contract_owner_address.serialize(ref constuctor_arg);
    hash.serialize(ref constuctor_arg);

    let (contract_address, _) = ContractClassTrait::deploy(contract, @constuctor_arg).unwrap();

    (contract_address, *contract.class_hash)
}

fn deploy_event_n_org_contract(
    name: ByteArray,
    hash: ClassHash,
    _token_address: ContractAddress,
    sponsor_contract_address: ContractAddress,
) -> (ContractAddress, ClassHash) {
    let contract = declare(name).unwrap().contract_class();

    let mut constuctor_arg = ArrayTrait::new();
    let contract_owner_address: ContractAddress = contract_address_const::<'admin'>();

    contract_owner_address.serialize(ref constuctor_arg);
    hash.serialize(ref constuctor_arg);
    _token_address.serialize(ref constuctor_arg);
    sponsor_contract_address.serialize(ref constuctor_arg);

    let (contract_address, _) = ContractClassTrait::deploy(contract, @constuctor_arg).unwrap();

    (contract_address, *contract.class_hash)
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


#[test]
fn test_course_upgradeability() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    //first deployment here
    let (contract_address, course_hash) = deploy_contract("AttenSysCourse", hash);

    //second deployment here
    let (new_contract_address, new_course_hash) = deploy_contract("AttenSysCourse", hash);

    let admin: ContractAddress = contract_address_const::<'admin'>();

    let attensys_course_contract = IAttenSysCourseDispatcher { contract_address };

    start_cheat_caller_address(contract_address, admin);
    attensys_course_contract.upgrade(new_course_hash);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic]
fn test_fake_course_contract_upgradeability() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    //first deployment here
    let (contract_address, course_hash) = deploy_contract("AttenSysCourse", hash);

    //second deployment here
    let (new_contract_address, new_course_hash) = deploy_contract("AttenSysCourse", hash);

    let fake_admin: ContractAddress = contract_address_const::<'fake_admin'>();

    let attensys_course_contract = IAttenSysCourseDispatcher { contract_address };

    start_cheat_caller_address(contract_address, fake_admin);
    attensys_course_contract.upgrade(new_course_hash);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_event_contract_upgradeability() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    // mock event with test addresses for first deployment
    let (contract_address, hash) = deploy_event_n_org_contract(
        "AttenSysEvent", hash, test_address(), test_address(),
    );

    // mock event with test addresses for second deployment
    let (new_contract_address, new_hash) = deploy_event_n_org_contract(
        "AttenSysEvent", hash, test_address(), test_address(),
    );

    let admin: ContractAddress = contract_address_const::<'admin'>();
    let attensys_event_contract = IAttenSysEventDispatcher { contract_address };
    start_cheat_caller_address(contract_address, admin);
    attensys_event_contract.upgrade(new_hash);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_org_contract_upgradeability() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    // mock org with test addresses for first deployment
    let (contract_address, hash) = deploy_event_n_org_contract(
        "AttenSysOrg", hash, test_address(), test_address(),
    );

    // mock org with test addresses for second deployment
    let (new_contract_address, new_hash) = deploy_event_n_org_contract(
        "AttenSysOrg", hash, test_address(), test_address(),
    );

    let admin: ContractAddress = contract_address_const::<'admin'>();
    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, admin);
    dispatcher.upgrade(new_hash);
    stop_cheat_caller_address(contract_address);
}
