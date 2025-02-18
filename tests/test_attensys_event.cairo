use starknet::{ContractAddress, contract_address_const, ClassHash};
use core::array::ArrayTrait;
use core::byte_array::ByteArray;
use core::integer::u256;
use snforge_std::{
    declare, ContractClassTrait,
    start_cheat_caller_address, stop_cheat_caller_address, test_address,
    start_cheat_block_timestamp_global
};

use attendsys::contracts::AttenSysEvent::{
    IAttenSysEventDispatcher,
    IAttenSysEventDispatcherTrait
};
use attendsys::contracts::AttenSysOrg::{IAttenSysOrgDispatcher, IAttenSysOrgDispatcherTrait};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

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
    let name_: ByteArray = "AttenSys";
    let symbol: ByteArray = "ATS";

    let mut constructor_calldata = ArrayTrait::new();

    token_uri.serialize(ref constructor_calldata);
    name_.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);

    let contract = declare(name).unwrap();
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    (contract_address, contract.class_hash)
}

fn deploy_event_contract(
    name: ByteArray,
    hash: ClassHash,
    _token_address: ContractAddress,
    sponsor_contract_address: ContractAddress
) -> ContractAddress {
    let contract = declare(name).unwrap();

    let mut constuctor_arg = ArrayTrait::new();
    let contract_owner_address: ContractAddress = contract_address_const::<'admin'>();

    contract_owner_address.serialize(ref constuctor_arg);
    hash.serialize(ref constuctor_arg);
    _token_address.serialize(ref constuctor_arg);
    sponsor_contract_address.serialize(ref constuctor_arg);

    let (contract_address, _) = contract.deploy(@constuctor_arg).unwrap();

    contract_address
}

fn deploy_erc20_token(name: ByteArray) -> ContractAddress {
    let contract = declare("AttenSysToken").unwrap();
    let mut constructor_calldata = ArrayTrait::new();
    
    let name: ByteArray = "Test Token";
    let symbol: ByteArray = "TST";
    let initial_supply: u256 = 1000000_u256;
    let owner: ContractAddress = contract_address_const::<'admin'>();
    
    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    initial_supply.serialize(ref constructor_calldata);
    owner.serialize(ref constructor_calldata);
    
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

fn deploy_org_contract(
    name: ByteArray,
    hash: ClassHash,
    token_address: ContractAddress,
    sponsor_contract: ContractAddress
) -> ContractAddress {
    let contract = declare(name).unwrap();
    let mut constructor_calldata = ArrayTrait::new();
    let admin: ContractAddress = contract_address_const::<'admin'>();

    admin.serialize(ref constructor_calldata);
    hash.serialize(ref constructor_calldata);
    token_address.serialize(ref constructor_calldata);
    sponsor_contract.serialize(ref constructor_calldata);

    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

fn setup_organization(
    org_contract: IAttenSysOrgDispatcher,
    org_address: ContractAddress,
    admin: ContractAddress,
    event_creator: ContractAddress,
    sponsor_contract: ContractAddress,
    token_address: ContractAddress
) {
    start_cheat_caller_address(org_address, admin);
    org_contract.create_org_profile(
        "Test Org",
        "Test URI"
    );
    stop_cheat_caller_address(org_address);

    start_cheat_caller_address(org_address, admin);
    org_contract.setSponsorShipAddress(sponsor_contract);
    stop_cheat_caller_address(org_address);

    start_cheat_caller_address(org_address, admin);
    let mut instructors = ArrayTrait::new();
    instructors.append(event_creator);
    org_contract.add_instructor_to_org(instructors, "Test Org");
    stop_cheat_caller_address(org_address);
}

#[test]
fn test_transfer_admin() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    // mock event with test addresses
    let contract_address = deploy_event_contract(
        "AttenSysEvent", hash, test_address(), test_address()
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
        "AttenSysEvent", hash, test_address(), test_address()
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
        'admin claim failed'
    );
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'unauthorized caller')]
fn test_transfer_admin_should_panic_for_wrong_admin() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    // mock event with test addresses
    let contract_address = deploy_event_contract(
        "AttenSysEvent", hash, test_address(), test_address()
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
        "AttenSysEvent", hash, test_address(), test_address()
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
fn test_sponsor_event_storage_update() {
    // Setup de contratos
    let (_, nft_hash) = deploy_nft_contract("AttenSysNft");
    let token_address = deploy_erc20_token("TestToken");
    let sponsor_contract = deploy_contract("AttenSysSponsor", nft_hash);
    let org_address = deploy_org_contract("AttenSysOrg", nft_hash, token_address, sponsor_contract);
    let contract_address = deploy_event_contract(
        "AttenSysEvent", 
        nft_hash,
        token_address,
        sponsor_contract
    );

    let _admin = contract_address_const::<'admin'>();
    let event_creator = contract_address_const::<'creator'>();
    let org_contract = IAttenSysOrgDispatcher { contract_address: org_address };
    let event_contract = IAttenSysEventDispatcher { contract_address: contract_address };

    // 1. Create the organization profile as an administrator
    start_cheat_caller_address(org_address, _admin);
    org_contract.create_org_profile(
        "Test Org",
        "Test URI"
    );
    org_contract.setSponsorShipAddress(sponsor_contract);
    stop_cheat_caller_address(org_address);

    // Add event_creator as instructor first
    start_cheat_caller_address(org_address, _admin);
    let mut instructors = ArrayTrait::new();
    instructors.append(event_creator);
    org_contract.add_instructor_to_org(instructors, "Test Org");
    stop_cheat_caller_address(org_address);

    // 2. Approve tokens for the organization
    start_cheat_caller_address(token_address, _admin);
    let _token = IERC20Dispatcher { contract_address: token_address };
    _token.approve(org_address, 10000_u256);
    _token.approve(sponsor_contract, 10000_u256);
    _token.transfer(org_address, 10000_u256);
    stop_cheat_caller_address(token_address);

    // 3. Approve tokens from org to sponsor contract
    start_cheat_caller_address(org_address, _admin);
    _token.approve(sponsor_contract, 10000_u256);
    stop_cheat_caller_address(org_address);

    // 4. Verify that the organization has the tokens
    let org_balance = _token.balance_of(org_address);
    assert(org_balance >= 10000_u256, 'Org needs tokens');

    // 5. Create the event
    start_cheat_caller_address(contract_address, event_creator);
    let _deployed_event = event_contract.create_event(
        event_creator,
        "Test Event",
        "Base URI",
        "Name",
        "Symbol",
        0_u256,
        1234657890_u256,
        true
    );
    let event_id = 1_u256;
    event_contract.register_for_event(event_id);
    stop_cheat_caller_address(contract_address);

    // 6. Enable sponsorship
    start_cheat_caller_address(contract_address, event_creator);
    event_contract.enable_sponsorship(_deployed_event, 1_u256, "sponsor_uri");
    event_contract.start_sponsorship(_deployed_event, 1_u256, "sponsor_uri");
    stop_cheat_caller_address(contract_address);

    // 7. Set the timestamp for the event to be active
    start_cheat_block_timestamp_global(1234567891_u64);

    // 9. Sponsor through the organization
    start_cheat_caller_address(org_address, _admin);
    org_contract.sponsor_organization(_deployed_event, "sponsor_uri", 1000_u256);
    stop_cheat_caller_address(org_address);

    // 10. Verify storage update
    let final_balance = event_contract.get_event_sponsorship_balance(_deployed_event);
    assert(final_balance == 1000_u256, 'Balance not updated');
}

#[test]
fn test_tokens_to_sponsor_contract() {
    // Setup contracts
    let (_, nft_hash) = deploy_nft_contract("AttenSysNft");
    let token_address = deploy_erc20_token("TestToken");
    let sponsor_contract = deploy_contract("AttenSysSponsor", nft_hash);
    let org_address = deploy_org_contract("AttenSysOrg", nft_hash, token_address, sponsor_contract);
    let contract_address = deploy_event_contract(
        "AttenSysEvent", 
        nft_hash,
        token_address,
        sponsor_contract
    );

    let _admin = contract_address_const::<'admin'>();
    let event_creator = contract_address_const::<'creator'>();
    let org_contract = IAttenSysOrgDispatcher { contract_address: org_address };
    let event_contract = IAttenSysEventDispatcher { contract_address: contract_address };

    // Create organization profile first
    start_cheat_caller_address(org_address, _admin);
    org_contract.create_org_profile(
        "Test Org",
        "Test URI"
    );
    org_contract.setSponsorShipAddress(sponsor_contract);
    stop_cheat_caller_address(org_address);

    // Add event_creator as instructor first
    start_cheat_caller_address(org_address, _admin);
    let mut instructors = ArrayTrait::new();
    instructors.append(event_creator);
    org_contract.add_instructor_to_org(instructors, "Test Org");
    stop_cheat_caller_address(org_address);

    // Then set sponsorship address
    start_cheat_caller_address(org_address, _admin);
    org_contract.setSponsorShipAddress(sponsor_contract);
    stop_cheat_caller_address(org_address);

    // Only after organization setup, approve token spending
    start_cheat_caller_address(token_address, _admin);
    let _token = IERC20Dispatcher { contract_address: token_address };
    _token.approve(org_address, 10000_u256);
    _token.approve(sponsor_contract, 10000_u256);
    _token.transfer(org_address, 10000_u256);
    stop_cheat_caller_address(token_address);

    // Approve tokens from org to sponsor contract
    start_cheat_caller_address(org_address, _admin);
    _token.approve(sponsor_contract, 10000_u256);
    stop_cheat_caller_address(org_address);

    // Create and sponsor event
    start_cheat_caller_address(contract_address, event_creator);
    let _deployed_event = event_contract.create_event(
        event_creator,
        "Test Event",
        "Base URI",
        "Name",
        "Symbol",
        0_u256,
        1234657890_u256,
        true
    );
    let event_id = 1_u256;
    event_contract.register_for_event(event_id);
    stop_cheat_caller_address(contract_address);

    // Enable and start sponsorship first
    start_cheat_caller_address(contract_address, event_creator);
    event_contract.enable_sponsorship(_deployed_event, 1_u256, "sponsor_uri");
    event_contract.start_sponsorship(_deployed_event, 1_u256, "sponsor_uri");
    stop_cheat_caller_address(contract_address);

    // Get initial balances
    let initial_sponsor_balance = _token.balance_of(sponsor_contract);
    
    // Sponsor event
    start_cheat_caller_address(org_address, _admin);
    org_contract.sponsor_organization(_deployed_event, "sponsor_uri", 1000_u256);
    stop_cheat_caller_address(org_address);

    // Verify tokens went to sponsor contract
    let final_sponsor_balance = _token.balance_of(sponsor_contract);
    assert(final_sponsor_balance == initial_sponsor_balance + 1000_u256, 'Wrong sponsor balance');
}

#[test]
#[should_panic(expected: 'not an expected caller.')]
fn test_withdraw_by_non_creator() {
    // Setup contracts
    let (_, nft_hash) = deploy_nft_contract("AttenSysNft");
    let token_address = deploy_erc20_token("TestToken");
    let sponsor_contract = deploy_contract("AttenSysSponsor", nft_hash);
    let org_address = deploy_org_contract("AttenSysOrg", nft_hash, token_address, sponsor_contract);
    let _contract_address = deploy_event_contract(
        "AttenSysEvent", 
        nft_hash, 
        token_address,
        sponsor_contract
    );

    let _admin = contract_address_const::<'admin'>();
    let event_creator = contract_address_const::<'creator'>();
    let _non_creator = contract_address_const::<'non_creator'>();
    let org_contract = IAttenSysOrgDispatcher { contract_address: org_address };
    let _event_contract = IAttenSysEventDispatcher { contract_address: _contract_address };

    // Create organization profile first
    start_cheat_caller_address(org_address, _admin);
    org_contract.create_org_profile(
        "Test Org",
        "Test URI"
    );
    org_contract.setSponsorShipAddress(sponsor_contract);
    stop_cheat_caller_address(org_address);

    // Then set sponsorship address
    start_cheat_caller_address(org_address, _admin);
    org_contract.setSponsorShipAddress(sponsor_contract);
    stop_cheat_caller_address(org_address);

    // Finally add event_creator as instructor
    start_cheat_caller_address(org_address, _admin);
    let mut instructors = ArrayTrait::new();
    instructors.append(event_creator);
    org_contract.add_instructor_to_org(instructors, "Test Org");
    stop_cheat_caller_address(org_address);

    // Only after organization setup, approve token spending
    start_cheat_caller_address(token_address, _admin);
    let _token = IERC20Dispatcher { contract_address: token_address };
    _token.approve(org_address, 10000_u256);
    _token.approve(sponsor_contract, 10000_u256);
    _token.transfer(org_address, 10000_u256);
    stop_cheat_caller_address(token_address);

    // Approve tokens from org to sponsor contract
    start_cheat_caller_address(org_address, _admin);
    _token.approve(sponsor_contract, 10000_u256);
    stop_cheat_caller_address(org_address);

    // Create and sponsor event
    start_cheat_caller_address(_contract_address, event_creator);
    let _deployed_event = _event_contract.create_event(
        event_creator,
        "Test Event",
        "Base URI",
        "Name",
        "Symbol",
        0_u256,
        1234657890_u256,
        true
    );
    let event_id = 1_u256;
    _event_contract.register_for_event(event_id);
    stop_cheat_caller_address(_contract_address);

    // Enable and start sponsorship first
    start_cheat_caller_address(_contract_address, event_creator);
    _event_contract.enable_sponsorship(_deployed_event, 1_u256, "sponsor_uri");
    _event_contract.start_sponsorship(_deployed_event, 1_u256, "sponsor_uri");
    stop_cheat_caller_address(_contract_address);

    // 10. Set the timestamp for the event to be active
    start_cheat_block_timestamp_global(1234567891_u64);

    // 11. Sponsor event
    start_cheat_caller_address(org_address, _admin);
    org_contract.sponsor_organization(_deployed_event, "sponsor_uri", 1_u256);
    stop_cheat_caller_address(org_address);

    // 13. Creator withdraws funds
    start_cheat_caller_address(_deployed_event, _non_creator);
    _event_contract.withdraw_sponsorship_funds(1000_u256);
    stop_cheat_caller_address(_deployed_event);
}

#[test]
fn test_complete_sponsorship_flow() {
    // Setup contracts
    let (_, nft_hash) = deploy_nft_contract("AttenSysNft");
    let token_address = deploy_erc20_token("TestToken");
    let sponsor_contract = deploy_contract("AttenSysSponsor", nft_hash);
    let org_address = deploy_org_contract("AttenSysOrg", nft_hash, token_address, sponsor_contract);
    let _contract_address = deploy_event_contract(
        "AttenSysEvent", 
        nft_hash, 
        token_address,
        sponsor_contract
    );

    let _admin = contract_address_const::<'admin'>();
    let event_creator = contract_address_const::<'creator'>();
    let org_contract = IAttenSysOrgDispatcher { contract_address: org_address };
    let _event_contract = IAttenSysEventDispatcher { contract_address: _contract_address };

    // Create organization profile first
    start_cheat_caller_address(org_address, _admin);
    org_contract.create_org_profile(
        "Test Org",
        "Test URI"
    );
    org_contract.setSponsorShipAddress(sponsor_contract);
    stop_cheat_caller_address(org_address);

    // Add event_creator as instructor first
    start_cheat_caller_address(org_address, _admin);
    let mut instructors = ArrayTrait::new();
    instructors.append(event_creator);
    org_contract.add_instructor_to_org(instructors, "Test Org");
    stop_cheat_caller_address(org_address);

    // 3. Approve tokens for the organization
    start_cheat_caller_address(token_address, _admin);
    let _token = IERC20Dispatcher { contract_address: token_address };
    _token.approve(org_address, 10000_u256);
    _token.approve(sponsor_contract, 10000_u256);
    _token.transfer(org_address, 10000_u256);
    stop_cheat_caller_address(token_address);

    // Approve tokens from org to sponsor contract
    start_cheat_caller_address(org_address, _admin);
    _token.approve(sponsor_contract, 10000_u256);
    stop_cheat_caller_address(org_address);

    // 7. Verify that the organization has the tokens
    let org_balance = _token.balance_of(org_address);
    assert(org_balance >= 10000_u256, 'Org needs tokens');

    // 8. Create the event
    start_cheat_caller_address(_contract_address, event_creator);
    let _deployed_event = _event_contract.create_event(
        event_creator,
        "Test Event",
        "Base URI",
        "Name",
        "Symbol",
        0_u256,
        1234657890_u256,
        true
    );
    let event_id = 1_u256;
    _event_contract.register_for_event(event_id);
    stop_cheat_caller_address(_contract_address);

    // 9. Enable sponsorship
    start_cheat_caller_address(_contract_address, event_creator);
    _event_contract.enable_sponsorship(_deployed_event, 1_u256, "sponsor_uri");
    _event_contract.start_sponsorship(_deployed_event, 1_u256, "sponsor_uri");
    stop_cheat_caller_address(_contract_address);

    // 10. Set the timestamp for the event to be active
    start_cheat_block_timestamp_global(1234567891_u64);

    // 11. Sponsor event
    start_cheat_caller_address(org_address, _admin);
    org_contract.sponsor_organization(_deployed_event, "sponsor_uri", 1_u256);
    stop_cheat_caller_address(org_address);

    // 13. Creator withdraws funds
    start_cheat_caller_address(_deployed_event, event_creator);
    _event_contract.withdraw_sponsorship_funds(1000_u256);
    stop_cheat_caller_address(_deployed_event);

    // Verify final balances
    let final_sponsor_balance = _token.balance_of(sponsor_contract);

    assert(final_sponsor_balance == 1000_u256, 'Wrong sponsor balance');
}
