use attendsys::contracts::course::AttenSysCourse::{
    IAttenSysCourseDispatcher, IAttenSysCourseDispatcherTrait,
};
use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::{ClassHash, ContractAddress, contract_address_const};


fn zero_address() -> ContractAddress {
    contract_address_const::<0>()
}

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
#[ignore]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8", block_tag: latest)]
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
    attensys_course_contract.create_course(owner, true, base_uri, name, symbol, base_uri_2, 0);
    stop_cheat_caller_address(contract_address);

    // wrong Owner attempts to remove course
    start_cheat_caller_address(contract_address, student);
    attensys_course_contract.remove_course(1); // Should fail

    stop_cheat_caller_address(contract_address);
}

#[test]
#[ignore]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8", block_tag: latest)]
fn test_remove_course_for_right_admin() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysCourse", hash);
    let attensys_course_contract = IAttenSysCourseDispatcher { contract_address };

    let owner: ContractAddress = contract_address_const::<'owner'>();
    let base_uri: ByteArray = "https://example.com/";
    let base_uri_2: ByteArray = "https://example.com/";
    let name: ByteArray = "Test Course";
    let symbol: ByteArray = "TC";

    start_cheat_caller_address(contract_address, owner);
    attensys_course_contract.create_course(owner, true, base_uri, name, symbol, base_uri_2, 0);
    assert(
        attensys_course_contract.get_course_nft_contract(1) != zero_address(),
        'course hasnt been created',
    );
    attensys_course_contract.remove_course(1);
    assert(
        attensys_course_contract.get_course_nft_contract(1) == zero_address(),
        'course hasnt been removed',
    );

    stop_cheat_caller_address(contract_address);
}


#[test]
#[ignore]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8", block_tag: latest)]
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
    attensys_course_contract.create_course(owner, true, base_uri, name, symbol, base_uri_2, 0);

    // Test initial completion status is false
    let initial_status = attensys_course_contract
        .check_course_completion_status_n_certification(1, student);
    assert(!initial_status, 'should be incomplete');

    // Complete course as student
    start_cheat_caller_address(contract_address, student);
    attensys_course_contract.acquire_a_course(1);
    attensys_course_contract.finish_course_claim_certification(1);

    // Test completion status is now true
    let completion_status = attensys_course_contract
        .check_course_completion_status_n_certification(1, student);
    assert(completion_status, 'should be complete');

    stop_cheat_caller_address(contract_address);
}


#[test]
#[ignore]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8", block_tag: latest)]
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
    attensys_course_contract.create_course(owner, true, base_uri, name, symbol, base_uri_2, 0);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, student);
    attensys_course_contract.acquire_a_course(0);
    assert(attensys_course_contract.is_user_taking_course(student, 0), 'not acquired');
    attensys_course_contract.acquire_a_course(0);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[ignore]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8", block_tag: latest)]
fn test_course_purchase() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysCourse", hash);
    let attensys_course_contract = IAttenSysCourseDispatcher { contract_address };

    let owner: ContractAddress = contract_address_const::<'owner'>();
    let student: felt252 = 0x05Bf9E38B116B37A8249a4cd041D402903a5E8a67C1a99d2D336ac7bd8B4034e;
    let base_uri: ByteArray = "https://example.com/";
    let base_uri_2: ByteArray = "https://example.com/";
    let name: ByteArray = "Test Course";
    let symbol: ByteArray = "TC";

    const STRK_CONTRACT_ADDRESS: felt252 =
        0x04718f5a0Fc34cC1AF16A1cdee98fFB20C31f5cD61D6Ab07201858f4287c938D;

    start_cheat_caller_address(contract_address, owner);
    attensys_course_contract.create_course(owner, true, base_uri, name, symbol, base_uri_2, 10);
    stop_cheat_caller_address(contract_address);

    //approve contract to spend token
    start_cheat_caller_address(
        STRK_CONTRACT_ADDRESS.try_into().unwrap(), student.try_into().unwrap(),
    );
    let token_dispatcher = ERC20ABIDispatcher {
        contract_address: STRK_CONTRACT_ADDRESS.try_into().unwrap(),
    };
    let balance = token_dispatcher.balance_of(student.try_into().unwrap());
    println!("student balance before purchase: {}", balance);
    let first_balance = token_dispatcher.balance_of(contract_address);
    println!("contract balance before purchase: {}", first_balance);
    token_dispatcher.approve(contract_address, 500000000000000000000000000);
    stop_cheat_caller_address(STRK_CONTRACT_ADDRESS.try_into().unwrap());

    start_cheat_caller_address(contract_address, student.try_into().unwrap());
    attensys_course_contract.acquire_a_course(1);
    assert(
        attensys_course_contract.is_user_taking_course(student.try_into().unwrap(), 1),
        'not acquired',
    );
    let second_balance = token_dispatcher.balance_of(contract_address);
    println!("contract balance after purchase: {}", second_balance);
    stop_cheat_caller_address(contract_address);
}


#[test]
#[ignore]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8", block_tag: latest)]
fn test_purchase_course_completions_n_withdrawals() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysCourse", hash);
    let attensys_course_contract = IAttenSysCourseDispatcher { contract_address };
    let contract_owner_address: ContractAddress = contract_address_const::<'admin'>();

    start_cheat_caller_address(contract_address, contract_owner_address.try_into().unwrap());
    attensys_course_contract.init_fee_percent(10);
    stop_cheat_caller_address(contract_address);

    let owner: felt252 = 0x0330c28cd779dE4d895c2B99C3878DD6CBB30C3Da3be117e83b9CB3b947E5A1A;
    let student1: felt252 = 0x05Bf9E38B116B37A8249a4cd041D402903a5E8a67C1a99d2D336ac7bd8B4034e;
    let student2: felt252 = 0x047EC7F6120Eb1aD7d037B40c37E9dDDfC5f3C7D6f63d49BE9683D278ccfF0ec;
    let base_uri: ByteArray = "https://example.com/";
    let base_uri_2: ByteArray = "https://example.com/";
    let name: ByteArray = "Test Course";
    let symbol: ByteArray = "TC";

    const STRK_CONTRACT_ADDRESS: felt252 =
        0x04718f5a0Fc34cC1AF16A1cdee98fFB20C31f5cD61D6Ab07201858f4287c938D;

    let course_creator_address: ContractAddress = contract_address_const::<'course_creator'>();
    start_cheat_caller_address(contract_address, course_creator_address);
    attensys_course_contract
        .create_course(course_creator_address, true, base_uri, name, symbol, base_uri_2, 1);

    let initial_count = attensys_course_contract.get_total_course_completions(1);
    assert(initial_count == 0, 'initial count should be 0');

    //approve contract to spend token
    start_cheat_caller_address(
        STRK_CONTRACT_ADDRESS.try_into().unwrap(), student1.try_into().unwrap(),
    );
    let token_dispatcher = ERC20ABIDispatcher {
        contract_address: STRK_CONTRACT_ADDRESS.try_into().unwrap(),
    };
    let balance = token_dispatcher.balance_of(student1.try_into().unwrap());
    println!("student1 balance before purchase: {}", balance);
    let first_contract_balance = token_dispatcher.balance_of(contract_address);
    println!("contract balance before student 1 purchase: {}", first_contract_balance);
    token_dispatcher.approve(contract_address, 50000000000000000000000000);
    stop_cheat_caller_address(STRK_CONTRACT_ADDRESS.try_into().unwrap());

    start_cheat_caller_address(
        STRK_CONTRACT_ADDRESS.try_into().unwrap(), student2.try_into().unwrap(),
    );
    let token_dispatcher = ERC20ABIDispatcher {
        contract_address: STRK_CONTRACT_ADDRESS.try_into().unwrap(),
    };
    let balance_two = token_dispatcher.balance_of(student2.try_into().unwrap());
    println!("student2 balance before purchase: {}", balance_two);
    let second_contract_balance = token_dispatcher.balance_of(contract_address);
    println!("contract balance before student 2 purchase: {}", second_contract_balance);
    token_dispatcher.approve(contract_address, 50000000000000000000000000);
    stop_cheat_caller_address(STRK_CONTRACT_ADDRESS.try_into().unwrap());

    start_cheat_caller_address(contract_address, student1.try_into().unwrap());
    attensys_course_contract.acquire_a_course(1);
    assert(
        attensys_course_contract.is_user_taking_course(student1.try_into().unwrap(), 1),
        'not acquired',
    );
    let new_balance_first = token_dispatcher.balance_of(contract_address);
    let review_status = attensys_course_contract.get_review_status(1, student1.try_into().unwrap());
    assert(!review_status, 'should be false');
    attensys_course_contract.review(1);
    assert(
        attensys_course_contract.get_review_status(1, student1.try_into().unwrap()),
        'should be true',
    );
    println!("contract balance after student 1 purchase: {}", new_balance_first);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, student2.try_into().unwrap());
    attensys_course_contract.acquire_a_course(1);
    assert(
        attensys_course_contract.is_user_taking_course(student2.try_into().unwrap(), 1),
        'not acquired',
    );
    let new_balance_second = token_dispatcher.balance_of(contract_address);
    println!("contract balance after student 2 purchase: {}", new_balance_second);
    stop_cheat_caller_address(contract_address);

    // First student completes
    start_cheat_caller_address(contract_address, student1.try_into().unwrap());
    attensys_course_contract.finish_course_claim_certification(1);
    let count_after_first = attensys_course_contract.get_total_course_completions(1);
    assert(count_after_first == 1, 'count should be 1');

    // Second student completes
    start_cheat_caller_address(contract_address, student2.try_into().unwrap());
    attensys_course_contract.finish_course_claim_certification(1);
    let count_after_second = attensys_course_contract.get_total_course_completions(1);
    assert(count_after_second == 2, 'count should be 2');

    stop_cheat_caller_address(contract_address);
    //testing creator withdraw
    start_cheat_caller_address(contract_address, course_creator_address);
    let balance_before_creator_withdrawal = token_dispatcher.balance_of(course_creator_address);
    println!("contract balance before creator withdrawing: {}", balance_before_creator_withdrawal);
    let creator_withdrawable = attensys_course_contract
        .get_creator_withdrawable_amount(course_creator_address);
    println!("creator withdrawable amount: {}", creator_withdrawable);
    attensys_course_contract.creator_withdraw(creator_withdrawable.try_into().unwrap());
    let balance_after_creator_withdrawal = token_dispatcher.balance_of(contract_address);
    // println!("contract balance after creator withdrawing 20 strk minus 2 strk fee: {}",
    // balance_after_creator_withdrawal);
    println!(
        "contract balance after creator withdrawing all strk minus fee: {}",
        balance_after_creator_withdrawal,
    );
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, contract_owner_address.try_into().unwrap());
    let balance_before_admin_start_withdrawal = token_dispatcher.balance_of(contract_address);
    println!(
        "contract balance before admin withdrawing all generated in fee: {}",
        balance_before_admin_start_withdrawal,
    );
    attensys_course_contract.admin_withdrawables(1);
    let balance_after_admin_withdrawal = token_dispatcher.balance_of(contract_address);
    let balance_after_creator_withdrawal = token_dispatcher.balance_of(course_creator_address);
    println!(
        "contract balance after admin withdrawing all generated in fee: {}",
        balance_after_admin_withdrawal,
    );
    println!(
        "contract balance after creator withdrawing all: {}", balance_after_creator_withdrawal,
    );

    stop_cheat_caller_address(contract_address);
}


#[test]
#[ignore]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8", block_tag: latest)]
#[should_panic(expected: 'Not admin')]
fn test_non_admin_cannot_suspend_or_unsuspend_course() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysCourse", hash);
    let attensys_course_contract = IAttenSysCourseDispatcher { contract_address };

    let owner: ContractAddress = contract_address_const::<'owner'>();
    let non_admin: ContractAddress = contract_address_const::<'student1'>();
    let course_id: u128 = 1;
    let base_uri: ByteArray = "https://example.com/";
    let base_uri_2: ByteArray = "https://example.com/";
    let name: ByteArray = "Test Course";
    let symbol: ByteArray = "TC";

    // Owner creates course
    start_cheat_caller_address(contract_address, owner);
    attensys_course_contract.create_course(owner, true, base_uri, name, symbol, base_uri_2, 0);
    stop_cheat_caller_address(contract_address);

    // Non-admin tries to suspend
    start_cheat_caller_address(contract_address, non_admin);

    attensys_course_contract.toggle_suspension(course_id, true); // Should fail
}

#[test]
#[ignore]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8", block_tag: latest)]
fn test_toggle_suspension() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysCourse", hash);
    let attensys_course_contract = IAttenSysCourseDispatcher { contract_address };

    let admin: ContractAddress = contract_address_const::<'admin'>();
    let course_identifier: u128 = 1;
    let base_uri: ByteArray = "https://example.com/";
    let base_uri_2: ByteArray = "https://example.com/";
    let name: ByteArray = "Test Course";
    let symbol: ByteArray = "TC";

    // Owner creates course
    start_cheat_caller_address(contract_address, admin);
    attensys_course_contract.create_course(admin, true, base_uri, name, symbol, base_uri_2, 0);
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

#[test]
#[ignore]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8", block_tag: latest)]
fn test_toggle_course_approval() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysCourse", hash);
    let attensys_course_contract = IAttenSysCourseDispatcher { contract_address };

    let admin: ContractAddress = contract_address_const::<'admin'>();
    let course_identifier: u128 = 1;
    let base_uri: ByteArray = "https://example.com/";
    let base_uri_2: ByteArray = "https://example.com/";
    let name: ByteArray = "Test Course";
    let symbol: ByteArray = "TC";

    // Owner creates course
    start_cheat_caller_address(contract_address, admin);
    attensys_course_contract.create_course(admin, true, base_uri, name, symbol, base_uri_2, 0);
    assert(
        attensys_course_contract.get_course_approval_status(course_identifier) == false,
        'course approved',
    );
    attensys_course_contract.toggle_course_approval(course_identifier, true);
    assert(
        attensys_course_contract.get_course_approval_status(course_identifier) == true,
        'course not approved',
    );

    stop_cheat_caller_address(contract_address);
}

