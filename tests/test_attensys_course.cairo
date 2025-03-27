use starknet::{ContractAddress, contract_address_const, ClassHash};

use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, stop_cheat_caller_address,
};

use attendsys::contracts::AttenSysCourse::{
    IAttenSysCourseDispatcher, IAttenSysCourseDispatcherTrait,
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
        'admin claim failed',
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

#[test]
#[should_panic(expected: 'not original creator')]
fn test_remove_course_for_wrong_admin() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysCourse", hash);
    let attensys_course_contract = IAttenSysCourseDispatcher { contract_address };

    let owner: ContractAddress = contract_address_const::<'owner'>();
    let student: ContractAddress = contract_address_const::<'student'>();
    let base_uri: ByteArray = "https://example.com/";
    let base_uri_2: ByteArray = "https://example.com/";
    let name: ByteArray = "Test Course";
    let symbol: ByteArray = "TC";

    start_cheat_caller_address(contract_address, owner);
    attensys_course_contract.create_course(owner, true, base_uri, name, symbol, base_uri_2);
    stop_cheat_caller_address(contract_address);

    
    // wrong Owner attempts to remove course
    start_cheat_caller_address(contract_address, student);
    attensys_course_contract.remove_course(1);  // Should fail


    stop_cheat_caller_address(contract_address);
}


#[test]
fn test_check_course_completion_status() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysCourse", hash);
    let attensys_course_contract = IAttenSysCourseDispatcher { contract_address };

    let owner: ContractAddress = contract_address_const::<'owner'>();
    let student: ContractAddress = contract_address_const::<'student'>();
    let base_uri: ByteArray = "https://example.com/";
    let base_uri_2: ByteArray = "https://example.com/";
    let name: ByteArray = "Test Course";
    let symbol: ByteArray = "TC";

    start_cheat_caller_address(contract_address, owner);
    attensys_course_contract.create_course(owner, true, base_uri, name, symbol, base_uri_2);

    // Test initial completion status is false
    let initial_status = attensys_course_contract
        .check_course_completion_status_n_certification(1, student);
    assert(!initial_status, 'should be incomplete');

    // Complete course as student
    start_cheat_caller_address(contract_address, student);
    attensys_course_contract.finish_course_claim_certification(1);

    // Test completion status is now true
    let completion_status = attensys_course_contract
        .check_course_completion_status_n_certification(1, student);
    assert(completion_status, 'should be complete');

    stop_cheat_caller_address(contract_address);
}


#[test]
#[should_panic(expected: 'already acquired')]
fn test_acquire_a_course() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysCourse", hash);
    let attensys_course_contract = IAttenSysCourseDispatcher { contract_address };

    let owner: ContractAddress = contract_address_const::<'owner'>();
    let student: ContractAddress = contract_address_const::<'student'>();
    let base_uri: ByteArray = "https://example.com/";
    let base_uri_2: ByteArray = "https://example.com/";
    let name: ByteArray = "Test Course";
    let symbol: ByteArray = "TC";

    start_cheat_caller_address(contract_address, owner);
    attensys_course_contract.create_course(owner, true, base_uri, name, symbol, base_uri_2);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, student);
    attensys_course_contract.acquire_a_course(0);
    assert(attensys_course_contract.is_user_taking_course(student, 0), 'not acquired');
    attensys_course_contract.acquire_a_course(0);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_get_total_course_completions() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysCourse", hash);
    let attensys_course_contract = IAttenSysCourseDispatcher { contract_address };

    let owner: ContractAddress = contract_address_const::<'owner'>();
    let student1: ContractAddress = contract_address_const::<'student1'>();
    let student2: ContractAddress = contract_address_const::<'student2'>();
    let base_uri: ByteArray = "https://example.com/";
    let base_uri_2: ByteArray = "https://example.com/";
    let name: ByteArray = "Test Course";
    let symbol: ByteArray = "TC";

    start_cheat_caller_address(contract_address, owner);
    attensys_course_contract.create_course(owner, true, base_uri, name, symbol, base_uri_2);

    let initial_count = attensys_course_contract.get_total_course_completions(1);
    assert(initial_count == 0, 'initial count should be 0');

    // First student completes
    start_cheat_caller_address(contract_address, student1);
    attensys_course_contract.finish_course_claim_certification(1);
    let count_after_first = attensys_course_contract.get_total_course_completions(1);
    assert(count_after_first == 1, 'count should be 1');

    // Second student completes
    start_cheat_caller_address(contract_address, student2);
    attensys_course_contract.finish_course_claim_certification(1);
    let count_after_second = attensys_course_contract.get_total_course_completions(1);
    assert(count_after_second == 2, 'count should be 2');

    stop_cheat_caller_address(contract_address);
}


#[test]
#[should_panic(expected: 'Not admin')]
fn test_non_admin_cannot_suspend_or_unsuspend_course() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysCourse", hash);
    let attensys_course_contract = IAttenSysCourseDispatcher { contract_address };

    let owner: ContractAddress = contract_address_const::<'owner'>();
    let non_admin: ContractAddress = contract_address_const::<'student1'>();
    let course_id: u256 = 1;
    let base_uri: ByteArray = "https://example.com/";
    let base_uri_2: ByteArray = "https://example.com/";
    let name: ByteArray = "Test Course";
    let symbol: ByteArray = "TC";

    // Owner creates course
    start_cheat_caller_address(contract_address, owner);
    attensys_course_contract.create_course(owner, true, base_uri, name, symbol, base_uri_2);
    stop_cheat_caller_address(contract_address);

    // Non-admin tries to suspend
    start_cheat_caller_address(contract_address, non_admin);

    attensys_course_contract.toggle_suspension(course_id, true); // Should fail
}

#[test]
fn test_toggle_suspension() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysCourse", hash);
    let attensys_course_contract = IAttenSysCourseDispatcher { contract_address };

    let admin: ContractAddress = contract_address_const::<'admin'>();
    let course_identifier: u256 = 1;
    let base_uri: ByteArray = "https://example.com/";
    let base_uri_2: ByteArray = "https://example.com/";
    let name: ByteArray = "Test Course";
    let symbol: ByteArray = "TC";

    // Owner creates course
    start_cheat_caller_address(contract_address, admin);
    attensys_course_contract.create_course(admin, true, base_uri, name, symbol, base_uri_2);
    // let current_suspension_status = attensys_course_contract.course_suspended.entry(1).read();

    //newly created course.is_suspended should be false
    assert(
        attensys_course_contract.get_suspension_status(course_identifier) == false,
        'course is suspended',
    );
    attensys_course_contract.toggle_suspension(course_identifier, true);
    //course.is_suspended should be true after toggle
    assert(
        attensys_course_contract.get_suspension_status(course_identifier) == true,
        'course is not suspended',
    );

    stop_cheat_caller_address(contract_address);
}

