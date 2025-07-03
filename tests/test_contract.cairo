// use attendsys::AttenSys::IAttenSysSafeDispatcher;
// use attendsys::AttenSys::IAttenSysSafeDispatcherTrait;
use attendsys::contracts::course::AttenSysCourse::{
    AttenSysCourse, IAttenSysCourseDispatcher, IAttenSysCourseDispatcherTrait,
};
use attendsys::contracts::event::AttenSysEvent::{
    IAttenSysEventDispatcher, IAttenSysEventDispatcherTrait,
};
use attendsys::contracts::mock::ERC20;
use attendsys::contracts::org::AttenSysOrg::AttenSysOrg::{
    ActiveMeetLinkAdded, BootCampCreated, BootCampSuspended, BootcampRegistration, BootcampRemoved,
    ChangeTier, Event, InstructorAddedToOrg, InstructorRemovedFromOrg, OrganizationProfile,
    OrganizationSuspended, RegistrationApproved, RegistrationDeclined, SetTierPrice, Tier,
};
use attendsys::contracts::org::AttenSysOrg::{IAttenSysOrgDispatcher, IAttenSysOrgDispatcherTrait};
// use attendsys::contracts::AttenSysSponsor:: { AttenSysSponsor, IAttenSysSponsorDispatcher };
// use attendsys::contracts::AttenSysSponsor::IAttenSysSponsorDispatcherTrait;
// use attendsys::contracts::AttenSysSponsor::IERC20Dispatcher;
// use attendsys::contracts::AttenSysSponsor::IERC20DispatcherTrait;
use attendsys::contracts::sponsor::AttenSysSponsor::AttenSysSponsor;
use attendsys::contracts::sponsor::AttenSysSponsor::{
    IAttenSysSponsorDispatcher, IAttenSysSponsorDispatcherTrait, IERC20Dispatcher,
    IERC20DispatcherTrait,
};
use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
// get_caller_address,
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_block_timestamp_global, start_cheat_caller_address, stop_cheat_caller_address,
    test_address,
};
use starknet::{ClassHash, ContractAddress, contract_address_const};

const STRK_ADDRESS: felt252 = 0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d;
const ACTUAL_STRK_HOLDER: felt252 =
    0x0168d601Be0C2bDCD09D7568d7Ed711D2A330Cd7488E7539fA66b56144EC998f;

#[starknet::interface]
pub trait IERC721<TContractState> {
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn safe_transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>,
    );
    fn transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256,
    );
    fn approve(ref self: TContractState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TContractState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool;

    // IERC721Metadata
    fn name(self: @TContractState) -> ByteArray;
    fn symbol(self: @TContractState) -> ByteArray;
    fn token_uri(self: @TContractState, token_id: u256) -> ByteArray;

    // NFT contract
    fn mint(ref self: TContractState, recipient: ContractAddress, token_id: u256);
}

// fn deploy_erc20_token() -> ContractAddress{
//     let sponsor_address: ContractAddress = contract_address_const::<'sponsor'>();
//     let initial_supply: u256 = 1_000_000_u256;

//     let contract_class = declare("AttenSysToken").unwrap().contract_class();

//     let mut constructor_args = ArrayTrait::new();
//     // initial_supply.serialize(ref constructor_args);
//     sponsor_address.serialize(ref constructor_args);

//     let (contract_address, _) = contract_class.deploy(@constructor_args).unwrap();

//     let balance = ERC20ABIDispatcher { contract_address }.balance_of(sponsor_address);
//     assert(balance == initial_supply, 'Incorrect initial balance');
//     contract_address
// }

fn deploy_contract(name: ByteArray, hash: ClassHash) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let mut constuctor_arg = ArrayTrait::new();
    let contract_owner_address: ContractAddress = contract_address_const::<
        'contract_owner_address',
    >();

    contract_owner_address.serialize(ref constuctor_arg);
    hash.serialize(ref constuctor_arg);
    let (contract_address, _) = ContractClassTrait::deploy(contract, @constuctor_arg).unwrap();
    contract_address
}


fn deploy_organization_contract(
    name: ByteArray,
    hash: ClassHash,
    _token_address: ContractAddress,
    sponsor_contract_address: ContractAddress,
) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();

    let mut constuctor_arg = ArrayTrait::new();

    let contract_owner_address: ContractAddress = contract_address_const::<
        'contract_owner_address',
    >();

    contract_owner_address.serialize(ref constuctor_arg);

    hash.serialize(ref constuctor_arg);

    _token_address.serialize(ref constuctor_arg);

    sponsor_contract_address.serialize(ref constuctor_arg);

    let (contract_address, _) = ContractClassTrait::deploy(contract, @constuctor_arg).unwrap();

    contract_address
}


fn deploy_sponsorship_contract(name: ByteArray, organization: ContractAddress) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();

    let mut constructor_arg = ArrayTrait::new();

    let contract_owner_address: ContractAddress = contract_address_const::<
        'contract_owner_address',
    >();

    let event: ContractAddress = contract_address_const::<'event_address'>();

    contract_owner_address.serialize(ref constructor_arg);

    organization.serialize(ref constructor_arg);

    event.serialize(ref constructor_arg);

    let (contract_address, _) = contract.deploy(@constructor_arg).unwrap();

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
#[ignore]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8", block_tag: latest)]
fn test_create_course() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysCourse", hash);
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let owner_address_two: ContractAddress = contract_address_const::<'owner_two'>();

    let dispatcher = IAttenSysCourseDispatcher { contract_address };
    let mut spy = spy_events();

    let token_uri_b: ByteArray = "https://dummy_uri.com/your_idb";
    let token_uri_b_2: ByteArray = "https://dummy_uri.com/your_idb";
    let token_uri_b_2: ByteArray = "https://dummy_uri.com/your_idb";
    let nft_name_b = "cairo";
    let nft_symb_b = "CAO";

    let token_uri_a: ByteArray = "https://dummy_uri.com/your_id";
    let token_uri_a_1: ByteArray = "https://dummy_uri.com/your_id";
    let nft_name_a = "cairo";
    let nft_symb_a = "CAO";
    start_cheat_caller_address(contract_address, owner_address);
    dispatcher
        .create_course(
            owner_address,
            true,
            token_uri_a.clone(),
            nft_name_a.clone(),
            nft_symb_a.clone(),
            token_uri_a_1,
            0,
        );
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    AttenSysCourse::Event::CourseCreated(
                        AttenSysCourse::CourseCreated {
                            course_identifier: 1,
                            owner_: owner_address,
                            accessment_: true,
                            base_uri: token_uri_a.clone(),
                            name_: nft_name_a,
                            symbol: nft_symb_a,
                            course_ipfs_uri: token_uri_a.clone(),
                            is_approved: false,
                        },
                    ),
                ),
            ],
        );
    dispatcher
        .create_course(
            owner_address,
            true,
            token_uri_b.clone(),
            nft_name_b.clone(),
            nft_symb_b.clone(),
            token_uri_b_2.clone(),
            0,
        );
    dispatcher
        .create_course(owner_address, true, token_uri_b, nft_name_b, nft_symb_b, token_uri_b_2, 0);

    let token_uri: ByteArray = "https://dummy_uri.com/your_idS";
    let token_uri_11: ByteArray = "https://dummy_uri.com/your_idS";
    let nft_name = "cairo";
    let nft_symb = "CAO";
    //call again
    start_cheat_caller_address(contract_address, owner_address_two);
    dispatcher
        .create_course(owner_address_two, true, token_uri, nft_name, nft_symb, token_uri_11, 0);
    let creator_courses = dispatcher.get_all_creator_courses(owner_address);
    let creator_courses_two = dispatcher.get_all_creator_courses(owner_address_two);
    let creator_info = dispatcher.get_creator_info(owner_address);

    let array_calldata = array![1, 2, 3];
    let course_info = dispatcher.get_course_infos(array_calldata);
    // assert(creator_courses.len() == 2, 'wrong count');
    // assert(creator_courses_two.len() == 1, 'wrong count');
    assert(*creator_courses.at(0).owner == owner_address, 'wrong owner');
    assert(*creator_courses.at(1).owner == owner_address, 'wrong owner');
    assert(*creator_courses_two.at(0).owner == owner_address_two, 'wrong owner');
    assert(creator_info.creator_status == true, 'failed not creator');
    assert(course_info.len() == 3, 'get course fail');
}

#[test]
#[ignore]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8", block_tag: latest)]
fn test_finish_course_n_claim() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysCourse", hash);
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let owner_address_two: ContractAddress = contract_address_const::<'owner_two'>();
    let viewer1_address: ContractAddress = contract_address_const::<'viewer1_address'>();
    let viewer2_address: ContractAddress = contract_address_const::<'viewer2_address'>();
    let viewer3_address: ContractAddress = contract_address_const::<'viewer3_address'>();

    let dispatcher = IAttenSysCourseDispatcher { contract_address };
    let mut spy = spy_events();

    let token_uri_b: ByteArray = "https://dummy_uri.com/your_idb";
    let token_uri_b_2: ByteArray = "https://dummy_uri.com/your_idb";
    let nft_name_b = "cairo_b";
    let nft_symb_b = "CAO";

    let token_uri_a: ByteArray = "https://dummy_uri.com/your_id";
    let token_uri_a_1: ByteArray = "https://dummy_uri.com/your_id";
    let nft_name_a = "cairo_a";
    let nft_symb_a = "CAO";
    start_cheat_caller_address(contract_address, owner_address);
    dispatcher
        .create_course(owner_address, true, token_uri_a, nft_name_a, nft_symb_a, token_uri_a_1, 0);
    dispatcher
        .create_course(owner_address, true, token_uri_b, nft_name_b, nft_symb_b, token_uri_b_2, 0);

    let token_uri: ByteArray = "https://dummy_uri.com/your_idS";
    let token_uri_2: ByteArray = "https://dummy_uri.com/your_idS";
    let nft_name = "cairo_c";
    let nft_symb = "CAO";
    //call again
    start_cheat_caller_address(contract_address, owner_address_two);
    dispatcher
        .create_course(owner_address_two, true, token_uri, nft_name, nft_symb, token_uri_2, 0);

    start_cheat_caller_address(contract_address, viewer1_address);
    dispatcher.finish_course_claim_certification(1);
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    AttenSysCourse::Event::CourseCertClaimed(
                        AttenSysCourse::CourseCertClaimed {
                            course_identifier: 1, candidate: viewer1_address,
                        },
                    ),
                ),
            ],
        );
    start_cheat_caller_address(contract_address, viewer2_address);
    dispatcher.finish_course_claim_certification(2);
    start_cheat_caller_address(contract_address, viewer3_address);
    dispatcher.finish_course_claim_certification(3);

    let nftContract_a = dispatcher.get_course_nft_contract(1);
    let nftContract_b = dispatcher.get_course_nft_contract(2);
    let nftContract_c = dispatcher.get_course_nft_contract(3);

    let erc721_token_a = IERC721Dispatcher { contract_address: nftContract_a };
    let erc721_token_b = IERC721Dispatcher { contract_address: nftContract_b };
    let erc721_token_c = IERC721Dispatcher { contract_address: nftContract_c };

    let token_name_a = erc721_token_a.name();
    let token_name_b = erc721_token_b.name();
    let token_name_c = erc721_token_c.name();

    assert(erc721_token_a.owner_of(1) == viewer1_address, 'wrong 1 token id');
    assert(erc721_token_b.owner_of(1) == viewer2_address, 'wrong 2 token id');
    assert(erc721_token_c.owner_of(1) == viewer3_address, 'wrong 3 token id');
    assert(token_name_a == "cairo_a", 'wrong token a name');
    assert(token_name_b == "cairo_b", 'wrong token b name');
    assert(token_name_c == "cairo_c", 'wrong token name');
}

#[test]
#[ignore]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8", block_tag: latest)]
fn test_add_replace_course_content() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let contract_address = deploy_contract("AttenSysCourse", hash);

    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let dispatcher = IAttenSysCourseDispatcher { contract_address };
    let mut spy = spy_events();

    let token_uri_a: ByteArray = "https://dummy_uri.com/your_id";
    let token_uri_a_1: ByteArray = "https://dummy_uri.com/your_id";
    let nft_name_a = "cairo_a";
    let nft_symb_a = "CAO";
    start_cheat_caller_address(contract_address, owner_address);
    dispatcher
        .create_course(owner_address, true, token_uri_a, nft_name_a, nft_symb_a, token_uri_a_1, 0);

    dispatcher.add_replace_course_content(1, owner_address, "123");
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    AttenSysCourse::Event::CourseReplaced(
                        AttenSysCourse::CourseReplaced {
                            course_identifier: 1, owner_: owner_address, new_course_uri: "123",
                        },
                    ),
                ),
            ],
        );
    let array_calldata = array![1];
    let course_info = dispatcher.get_course_infos(array_calldata);
    assert(course_info.at(0).uri == @"123", 'wrong first uri');

    let second_array_calldata = array![1];
    dispatcher.add_replace_course_content(1, owner_address, "555");
    let course_info = dispatcher.get_course_infos(second_array_calldata);
    assert(course_info.at(0).uri == @"555", 'wrong first uri');

    let all_courses_info = dispatcher.get_all_courses_info();
    assert(all_courses_info.len() > 0, 'non-write');
    assert(all_courses_info.at(0).uri == @"555", 'wrong uri replacement');

    let all_creator_courses = dispatcher.get_all_creator_courses(owner_address);
    assert(all_creator_courses.len() > 0, 'non write CC');
}

#[test]
fn test_create_event() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    // mock event with test addresses
    let contract_address = deploy_organization_contract(
        "AttenSysEvent", hash, test_address(), test_address(),
    );
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let owner_address_two: ContractAddress = contract_address_const::<'owner_two'>();
    let owner_address_three: ContractAddress = contract_address_const::<'owner_three'>();
    let dispatcher = IAttenSysEventDispatcher { contract_address };
    let token_uri: ByteArray = "https://dummy_uri.com/your_id";
    let event_name = "web3";
    let nft_name = "onlydust";
    let nft_symb = "OD";
    let event_uri: ByteArray = "QmExampleIPFSHash";

    // Create first event
    start_cheat_caller_address(contract_address, owner_address);
    dispatcher
        .create_event(
            owner_address,
            event_name.clone(),
            token_uri,
            nft_name,
            nft_symb,
            2238493,
            32989989,
            1,
            event_uri.clone(),
            0,
        );
    let event_details_check = dispatcher.get_event_details(1);
    //println!("Event URI: {:?}", event_details_check.event_uri);
    assert(event_details_check.event_name == event_name, 'wrong_name');
    assert(event_details_check.time.registration_open == 1, 'not set');
    assert(event_details_check.time.start_time == 2238493, 'wrong start');
    assert(event_details_check.time.end_time == 32989989, 'wrong end');
    assert(event_details_check.event_organizer == owner_address, 'wrong owner');
    assert(event_details_check.event_uri == event_uri, 'wrong uri');

    // Create second event

    start_cheat_caller_address(contract_address, owner_address_two);
    let token_uri_two: ByteArray = "https://dummy_uri.com/your_id";
    let event_name_two = "web2";
    let nft_name_two = "web3bridge";
    let nft_symb_two = "wb3";
    let event_uri_two: ByteArray = "QmYwAPJzv5CZsnAzt8auVZRnHJxF8d1swomC5nKkJY6Y3A";

    dispatcher
        .create_event(
            owner_address_two,
            event_name_two.clone(),
            token_uri_two,
            nft_name_two,
            nft_symb_two,
            2238493,
            32989989,
            1,
            event_uri_two.clone(),
            0,
        );

    let event_details_check_two = dispatcher.get_event_details(2);
    assert(event_details_check_two.event_name == event_name_two, 'wrong_name');
    assert(event_details_check_two.event_uri == event_uri_two, 'wrongg uri');

    // Create third event without event uri

    start_cheat_caller_address(contract_address, owner_address_three);
    let token_uri_three: ByteArray = "https://dummy_uri.com/your_id";
    let event_name_three = "web4";
    let nft_name_three = "frankyaccess";
    let nft_symb_three = "fac";
    let event_uri_3: ByteArray = "a";

    dispatcher
        .create_event(
            owner_address_three,
            event_name_three.clone(),
            token_uri_three,
            nft_name_three,
            nft_symb_three,
            2238493,
            32989989,
            1,
            event_uri_3.clone(),
            1,
        );

    let event_details_check_three = dispatcher.get_event_details(3);
    assert(event_details_check_three.event_name == event_name_three, 'wrong_name');
    assert(event_details_check_three.event_uri == event_uri_3, 'wronggg uri');
}

#[test]
fn test_reg_nd_mark() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    // mock event with test addresses
    let contract_address = deploy_organization_contract(
        "AttenSysEvent", hash, test_address(), test_address(),
    );
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let attendee1_address: ContractAddress = contract_address_const::<'attendee1_address'>();
    let attendee2_address: ContractAddress = contract_address_const::<'attendee2_address'>();
    let attendee3_address: ContractAddress = contract_address_const::<'attendee3_address'>();

    let dispatcher = IAttenSysEventDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    let token_uri: ByteArray = "https://dummy_uri.com/your_id";
    let event_name = "web3";
    let nft_name = "onlydust";
    let nft_symb = "OD";
    let event_uri: ByteArray = "QmExampleIPFSHash";

    start_cheat_caller_address(contract_address, owner_address);
    dispatcher
        .create_event(
            owner_address,
            event_name.clone(),
            token_uri,
            nft_name,
            nft_symb,
            223,
            329,
            1,
            event_uri,
            0,
        );

    start_cheat_block_timestamp_global(55555);
    let user_a_uri: ByteArray = "https://dummy_uri.com/your_id";
    let user_b_uri: ByteArray = "https://dummy_uri.com/your_id";
    let user_c_uri: ByteArray = "https://dummy_uri.com/your_id";

    start_cheat_caller_address(contract_address, attendee1_address);
    dispatcher.register_for_event(1, user_a_uri);
    dispatcher.mark_attendance(1, attendee1_address);
    let all_events = dispatcher.get_all_attended_events(attendee1_address);
    assert(all_events.len() == 1, 'wrong length');

    start_cheat_caller_address(contract_address, attendee2_address);
    dispatcher.register_for_event(1, user_b_uri);
    dispatcher.mark_attendance(1, attendee2_address);

    start_cheat_caller_address(contract_address, attendee3_address);
    dispatcher.register_for_event(1, user_c_uri);
    dispatcher.mark_attendance(1, attendee3_address);

    start_cheat_caller_address(contract_address, owner_address);
    dispatcher.batch_certify_attendees(1);

    let nftContract = dispatcher.get_event_nft_contract(1);

    let erc721_token = IERC721Dispatcher { contract_address: nftContract };
    let token_name = erc721_token.name();

    assert(erc721_token.owner_of(1) == attendee1_address, 'wrong 1 token id');
    assert(erc721_token.owner_of(2) == attendee2_address, 'wrong 2 token id');
    assert(erc721_token.owner_of(3) == attendee3_address, 'wrong 3 token id');
    assert(token_name == "onlydust", 'wrong token name');
    let attendance_stat = dispatcher.get_attendance_status(attendee3_address, 1);
    assert(attendance_stat == true, 'wrong attenStat');
}


#[test]
fn test_constructor() {
    let (contract_address, _) = deploy_nft_contract("AttenSysNft");

    let erc721_token = IERC721Dispatcher { contract_address };

    let token_name = erc721_token.name();
    let token_symbol = erc721_token.symbol();

    assert(token_name == "Attensys", 'wrong token name');
    assert(token_symbol == "ATS", 'wrong token symbol');
}

#[test]
fn test_mint() {
    let (contract_address, _) = deploy_nft_contract("AttenSysNft");

    let erc721_token = IERC721Dispatcher { contract_address };

    let token_recipient: ContractAddress = contract_address_const::<'recipient_address'>();

    erc721_token.mint(token_recipient, 1);

    assert(erc721_token.owner_of(1) == token_recipient, 'wrong token id');
    assert(erc721_token.balance_of(token_recipient) > 0, 'mint failed');
}

#[test]
fn test_create_org_profile() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();

    let mut spy = spy_events();

    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();

    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let owner_address: ContractAddress = contract_address_const::<'owner'>();

    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let org_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";

    let org_name_copy = org_name.clone();
    let org_ipfs_uri_copy = org_ipfs_uri.clone();
    dispatcher.create_org_profile(org_name, org_ipfs_uri);

    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Event::OrganizationProfile(
                        OrganizationProfile {
                            org_name: org_name_copy, org_ipfs_uri: org_ipfs_uri_copy,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_add_instructor_to_org() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();

    let mut spy = spy_events();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();

    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let instructor_address: ContractAddress = contract_address_const::<'instructor'>();

    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let org_name_copy = org_name.clone();
    let org_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    dispatcher.create_org_profile(org_name.clone(), org_ipfs_uri);

    let mut arr_of_instructors: Array<ContractAddress> = array![];

    arr_of_instructors.append(instructor_address);

    let arr_of_instructors_copy = arr_of_instructors.clone();
    dispatcher.add_instructor_to_org(arr_of_instructors, org_name);
    let org = dispatcher.get_org_info(owner_address);
    assert_eq!(org.number_of_instructors, 2);

    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Event::InstructorAddedToOrg(
                        InstructorAddedToOrg {
                            org_name: org_name_copy,
                            org_address: owner_address,
                            instructor: arr_of_instructors_copy,
                        },
                    ),
                ),
            ],
        )
}


#[test]
#[should_panic(expected: "already added.")]
fn test_add_instructor_to_org_already_added() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let instructor_address: ContractAddress = contract_address_const::<'instructor'>();
    let dispatcher = IAttenSysOrgDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let org_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    dispatcher.create_org_profile(org_name.clone(), org_ipfs_uri);

    let mut arr_of_instructors: Array<ContractAddress> = array![];
    arr_of_instructors.append(instructor_address);
    arr_of_instructors.append(instructor_address);
    dispatcher.add_instructor_to_org(arr_of_instructors, org_name);
}

#[test]
fn test_remove_instructor_from_org() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let mut spy = spy_events();
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let instructor_address: ContractAddress = contract_address_const::<'instructor'>();
    let instructor_address2: ContractAddress = contract_address_const::<'instructor2'>();
    let instructor_address3: ContractAddress = contract_address_const::<'instructor3'>();

    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let org_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    dispatcher.create_org_profile(org_name.clone(), org_ipfs_uri);
    let mut arr_of_instructors: Array<ContractAddress> = array![];
    arr_of_instructors.append(instructor_address);
    arr_of_instructors.append(instructor_address2);
    arr_of_instructors.append(instructor_address3);
    dispatcher.add_instructor_to_org(arr_of_instructors, org_name);
    let org = dispatcher.get_org_info(owner_address);
    assert_eq!(org.number_of_instructors, 4);
    dispatcher.remove_instructor_from_org(instructor_address3);
    let newOrg = dispatcher.get_org_info(owner_address);
    assert_eq!(newOrg.number_of_instructors, 3);

    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Event::InstructorRemovedFromOrg(
                        InstructorRemovedFromOrg {
                            instructor_addr: instructor_address3, org_owner: owner_address,
                        },
                    ),
                ),
            ],
        )
}

#[test]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8", block_tag: latest)]
fn test_create_free_bootcamp_for_org() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let instructor_address: ContractAddress = contract_address_const::<'instructor'>();

    let mut spy = spy_events();

    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let org_name_cp = org_name.clone();
    let bootcamp_name: ByteArray = "web3Bridge bootcamp";
    let bootcamp_name_cp = bootcamp_name.clone();
    let org_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    let bootcamp_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    let bootcamp_ipfs_uri_cp = bootcamp_ipfs_uri.clone();
    dispatcher.create_org_profile(org_name.clone(), org_ipfs_uri);
    let mut arr_of_instructors: Array<ContractAddress> = array![];
    arr_of_instructors.append(instructor_address);
    dispatcher.add_instructor_to_org(arr_of_instructors, org_name.clone());
    let org = dispatcher.get_org_info(owner_address);
    assert_eq!(org.number_of_instructors, 2);

    let token_uri: ByteArray = "https://dummy_uri.com";
    let token_uri_cp = token_uri.clone();
    let nft_name: ByteArray = "cairo";
    let nft_name_cp = nft_name.clone();
    let nft_symb: ByteArray = "CAO";
    let nft_symb_cp = nft_symb.clone();

    dispatcher
        .create_bootcamp(
            org_name, bootcamp_name, token_uri, nft_name, nft_symb, 3, bootcamp_ipfs_uri, 0,
        );
    let updatedOrg = dispatcher.get_org_info(owner_address);
    assert_eq!(updatedOrg.number_of_all_bootcamps, 1);
    assert_eq!(updatedOrg.number_of_all_classes, 3);

    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Event::BootCampCreated(
                        BootCampCreated {
                            org_name: org_name_cp,
                            org_address: owner_address,
                            bootcamp_name: bootcamp_name_cp,
                            nft_name: token_uri_cp,
                            nft_symbol: nft_name_cp,
                            nft_uri: nft_symb_cp,
                            num_of_classes: 3,
                            bootcamp_ipfs_uri: bootcamp_ipfs_uri_cp,
                            price: 0,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_create_paid_bootcamp_for_org() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let instructor_address: ContractAddress = contract_address_const::<'instructor'>();

    let mut spy = spy_events();

    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let org_name_cp = org_name.clone();
    let bootcamp_name: ByteArray = "web3Bridge bootcamp";
    let bootcamp_name_cp = bootcamp_name.clone();
    let org_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    let bootcamp_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    let bootcamp_ipfs_uri_cp = bootcamp_ipfs_uri.clone();
    dispatcher.create_org_profile(org_name.clone(), org_ipfs_uri);
    let mut arr_of_instructors: Array<ContractAddress> = array![];
    arr_of_instructors.append(instructor_address);
    dispatcher.add_instructor_to_org(arr_of_instructors, org_name.clone());
    let org = dispatcher.get_org_info(owner_address);
    assert_eq!(org.number_of_instructors, 2);

    let token_uri: ByteArray = "https://dummy_uri.com";
    let token_uri_cp = token_uri.clone();
    let nft_name: ByteArray = "cairo";
    let nft_name_cp = nft_name.clone();
    let nft_symb: ByteArray = "CAO";
    let nft_symb_cp = nft_symb.clone();

    dispatcher
        .create_bootcamp(
            org_name, bootcamp_name, token_uri, nft_name, nft_symb, 3, bootcamp_ipfs_uri, 100,
        );
    let updatedOrg = dispatcher.get_org_info(owner_address);
    assert_eq!(updatedOrg.number_of_all_bootcamps, 1);
    assert_eq!(updatedOrg.number_of_all_classes, 3);

    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Event::BootCampCreated(
                        BootCampCreated {
                            org_name: org_name_cp,
                            org_address: owner_address,
                            bootcamp_name: bootcamp_name_cp,
                            nft_name: token_uri_cp,
                            nft_symbol: nft_name_cp,
                            nft_uri: nft_symb_cp,
                            num_of_classes: 3,
                            bootcamp_ipfs_uri: bootcamp_ipfs_uri_cp,
                            price: 100,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_add_active_meet_link_to_bootcamp() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let mut spy = spy_events();
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let instructor_address: ContractAddress = contract_address_const::<'instructor'>();

    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let bootcamp_name: ByteArray = "web3Bridge bootcamp";
    let org_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    let bootcamp_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    dispatcher.create_org_profile(org_name.clone(), org_ipfs_uri);
    let mut arr_of_instructors: Array<ContractAddress> = array![];
    arr_of_instructors.append(instructor_address);
    dispatcher.add_instructor_to_org(arr_of_instructors, org_name.clone());
    let org = dispatcher.get_org_info(owner_address);
    assert_eq!(org.number_of_instructors, 2);

    let token_uri: ByteArray = "https://dummy_uri.com";
    let nft_name: ByteArray = "cairo";
    let nft_symb: ByteArray = "CAO";

    dispatcher
        .create_bootcamp(
            org_name, bootcamp_name, token_uri, nft_name, nft_symb, 3, bootcamp_ipfs_uri, 0,
        );

    // possible to override active meet link.
    dispatcher.add_active_meet_link("https:meet.google.com/hgf-snbh-snh", 0, false, owner_address);
    dispatcher.add_active_meet_link("https:meet.google.com/shd-snag-qro", 0, false, owner_address);
    dispatcher.add_active_meet_link("https:meet.google.com/mna-xbbh-snh", 0, true, owner_address);

    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Event::ActiveMeetLinkAdded(
                        ActiveMeetLinkAdded {
                            meet_link: "https:meet.google.com/hgf-snbh-snh",
                            bootcamp_id: 0,
                            is_instructor: false,
                            org_address: owner_address,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[ignore]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8", block_tag: latest)]
fn test_register_for_free_bootcamp() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let mut spy = spy_events();
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let instructor_address: ContractAddress = contract_address_const::<'instructor'>();
    let instructor_address_cp = instructor_address.clone();
    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let bootcamp_name: ByteArray = "web3Bridge bootcamp";
    let org_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    let bootcamp_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    dispatcher.create_org_profile(org_name.clone(), org_ipfs_uri);
    let mut arr_of_instructors: Array<ContractAddress> = array![];
    arr_of_instructors.append(instructor_address);
    dispatcher.add_instructor_to_org(arr_of_instructors, org_name.clone());
    let org = dispatcher.get_org_info(owner_address);
    let org_address: ContractAddress = org.address_of_org;
    let org_address_cp = org_address.clone();
    let token_uri: ByteArray = "https://dummy_uri.com";
    let token_uri_clone: ByteArray = "https://dummy_uri.com";
    let nft_name: ByteArray = "cairo";
    let nft_symb: ByteArray = "CAO";

    dispatcher
        .create_bootcamp(
            org_name, bootcamp_name, token_uri, nft_name, nft_symb, 3, bootcamp_ipfs_uri, 0,
        );

    dispatcher.register_for_bootcamp(org_address, 0, token_uri_clone);

    let all_request = dispatcher.get_all_registration_request(owner_address);
    let status: u8 = *all_request[0].status;
    assert(status == 0, 'not pending');

    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Event::BootcampRegistration(
                        BootcampRegistration { org_address: org_address_cp, bootcamp_id: 0 },
                    ),
                ),
            ],
        )
}

#[test]
#[ignore]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8", block_tag: latest)]
fn test_register_for_paid_bootcamp() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let mut spy = spy_events();
    let strk_address: ContractAddress = STRK_ADDRESS.try_into().unwrap();
    let student: felt252 = 0x05Bf9E38B116B37A8249a4cd041D402903a5E8a67C1a99d2D336ac7bd8B4034e;

    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let instructor_address: ContractAddress = contract_address_const::<'instructor'>();
    let instructor_address_cp = instructor_address.clone();
    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let bootcamp_name: ByteArray = "web3Bridge bootcamp";
    let org_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    let bootcamp_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    dispatcher.create_org_profile(org_name.clone(), org_ipfs_uri);
    let mut arr_of_instructors: Array<ContractAddress> = array![];
    arr_of_instructors.append(instructor_address);
    dispatcher.add_instructor_to_org(arr_of_instructors, org_name.clone());
    let org = dispatcher.get_org_info(owner_address);
    let org_address: ContractAddress = org.address_of_org;
    let org_address_cp = org_address.clone();
    let token_uri: ByteArray = "https://dummy_uri.com";
    let token_uri_clone: ByteArray = "https://dummy_uri.com";
    let nft_name: ByteArray = "cairo";
    let nft_symb: ByteArray = "CAO";

    dispatcher
        .create_bootcamp(
            org_name, bootcamp_name, token_uri, nft_name, nft_symb, 3, bootcamp_ipfs_uri, 10,
        );
    stop_cheat_caller_address(contract_address);

    // approve contract to spend token
    start_cheat_caller_address(strk_address, student.try_into().unwrap());
    let strk_dispatcher = ERC20ABIDispatcher { contract_address: strk_address };
    let balance = strk_dispatcher.balance_of(student.try_into().unwrap());
    println!("student balance before purchase: {}", balance);
    let first_balance = strk_dispatcher.balance_of(contract_address);
    println!("contract balance before purchase: {}", first_balance);
    strk_dispatcher.approve(contract_address, 500000000000000000000000000);
    stop_cheat_caller_address(strk_address);

    start_cheat_caller_address(contract_address, student.try_into().unwrap());

    println!("I got here, just before payment");
    dispatcher.register_for_bootcamp(org_address, 0, token_uri_clone);
    println!("I got here, just after payment");
    let second_balance = strk_dispatcher.balance_of(contract_address);
    println!("contract balance after purchase: {}", second_balance);

    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, owner_address);
    let all_request = dispatcher.get_all_registration_request(owner_address);
    let status: u8 = *all_request[0].status;
    assert(status == 0, 'not pending');
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Event::BootcampRegistration(
                        BootcampRegistration { org_address: org_address_cp, bootcamp_id: 0 },
                    ),
                ),
            ],
        )
}

#[test]
fn test_approve_registration() {
    //set required addreses
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let mut spy = spy_events();
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let instructor_address: ContractAddress = contract_address_const::<'instructor'>();
    let student_address: ContractAddress = contract_address_const::<'candidate'>();

    // setup dispatcher
    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let bootcamp_name: ByteArray = "web3Bridge bootcamp";
    let org_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    let bootcamp_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    dispatcher.create_org_profile(org_name.clone(), org_ipfs_uri);
    let mut arr_of_instructors: Array<ContractAddress> = array![];
    arr_of_instructors.append(instructor_address);
    dispatcher.add_instructor_to_org(arr_of_instructors, org_name.clone());
    let org = dispatcher.get_org_info(owner_address);
    let org_address: ContractAddress = org.address_of_org;

    let token_uri: ByteArray = "https://dummy_uri.com";
    let token_uri_clone_c: ByteArray = "https://dummy_uri.com";
    let nft_name: ByteArray = "cairo";
    let nft_symb: ByteArray = "CAO";
    dispatcher
        .create_bootcamp(
            org_name, bootcamp_name, token_uri, nft_name, nft_symb, 3, bootcamp_ipfs_uri, 0,
        );
    stop_cheat_caller_address(contract_address);

    let student_address_cp = student_address.clone();
    start_cheat_caller_address(contract_address, student_address_cp);
    dispatcher.register_for_bootcamp(owner_address, 0, token_uri_clone_c);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, owner_address);
    dispatcher.approve_registration(student_address, 0);
    stop_cheat_caller_address(contract_address);

    let updated_org = dispatcher.get_org_info(owner_address);
    let updated_org_num_of_students = updated_org.number_of_students;
    assert(updated_org_num_of_students == 1, 'inaccurate num of students');

    let all_request = dispatcher.get_all_registration_request(owner_address);
    let status: u8 = *all_request[0].status;
    assert(status == 1, 'not approved');

    let allbootcamp = dispatcher.get_registered_bootcamp(student_address);
    assert(allbootcamp.len() > 0, 'wrong regisration count');

    let specific_bootcamp = dispatcher
        .get_specific_organization_registered_bootcamp(owner_address, student_address);
    assert(specific_bootcamp.len() > 0, 'wrong specific count');

    start_cheat_caller_address(contract_address, student_address);
    dispatcher.mark_attendance_for_a_class(owner_address, owner_address, 0, 0);
    stop_cheat_caller_address(contract_address);
    let attendance_status = dispatcher
        .get_class_attendance_status(owner_address, 0, 0, student_address);
    assert(attendance_status, 'not marked');

    start_cheat_caller_address(contract_address, owner_address);
    dispatcher.batch_certify_students(owner_address, 0);
    let certify_length = dispatcher.get_certified_student_bootcamp_address(owner_address, 0);
    assert(certify_length.len() == 1, 'incorrect array len');
    let get_cert_stat = dispatcher
        .get_bootcamp_certification_status(owner_address, 0, student_address);
    assert(get_cert_stat, 'incorrect status');
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Event::RegistrationApproved(
                        RegistrationApproved {
                            student_address: student_address_cp, bootcamp_id: 0,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[ignore]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8", block_tag: latest)]
fn test_withdraw_bootcamp_funds() {
    //set required addreses
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let mut spy = spy_events();
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let instructor_address: ContractAddress = contract_address_const::<'instructor'>();
    let student1_address: ContractAddress = contract_address_const::<'student'>();
    let student2_address: ContractAddress = contract_address_const::<'student2'>();

    // setup dispatcher
    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let bootcamp_name: ByteArray = "web3Bridge bootcamp";
    let org_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    let bootcamp_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    dispatcher.create_org_profile(org_name.clone(), org_ipfs_uri);
    let mut arr_of_instructors: Array<ContractAddress> = array![];
    arr_of_instructors.append(instructor_address);
    dispatcher.add_instructor_to_org(arr_of_instructors, org_name.clone());
    let org = dispatcher.get_org_info(owner_address);
    let org_address: ContractAddress = org.address_of_org;

    let token_uri: ByteArray = "https://dummy_uri.com";
    // let token_uri2: ByteArray = "https://dummy_uri2.com";
    let token_uri_clone_c: ByteArray = "https://dummy_uri.com";
    let token_uri2_clone_c: ByteArray = "https://dummy_uri.com";
    let nft_name: ByteArray = "cairo";
    let nft_symb: ByteArray = "CAO";
    dispatcher
        .create_bootcamp(
            org_name, bootcamp_name, token_uri, nft_name, nft_symb, 3, bootcamp_ipfs_uri, 10,
        );
    stop_cheat_caller_address(contract_address);

    let student1_address_cp = student1_address.clone();
    start_cheat_caller_address(contract_address, student1_address_cp);
    dispatcher.register_for_bootcamp(owner_address, 0, token_uri_clone_c);
    stop_cheat_caller_address(contract_address);

    let student2_address_cp = student2_address.clone();
    start_cheat_caller_address(contract_address, student2_address_cp);
    dispatcher.register_for_bootcamp(owner_address, 0, token_uri2_clone_c);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, owner_address);
    dispatcher.approve_registration(student1_address, 0);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, owner_address);
    dispatcher.approve_registration(student2_address, 0);
    stop_cheat_caller_address(contract_address);

    let updated_org = dispatcher.get_org_info(owner_address);
    let updated_org_num_of_students = updated_org.number_of_students;
    assert(updated_org_num_of_students == 1, 'inaccurate num of students');

    let all_request = dispatcher.get_all_registration_request(owner_address);
    let status: u8 = *all_request[0].status;
    assert(status == 1, 'not approved');

    let allbootcamp = dispatcher.get_registered_bootcamp(student1_address);
    assert(allbootcamp.len() > 0, 'wrong regisration count');

    let specific_bootcamp = dispatcher
        .get_specific_organization_registered_bootcamp(owner_address, student1_address);
    assert(specific_bootcamp.len() == 2, 'wrong specific count');

    start_cheat_caller_address(contract_address, student1_address);
    dispatcher.mark_attendance_for_a_class(owner_address, owner_address, 0, 0);
    stop_cheat_caller_address(contract_address);
    let attendance_status = dispatcher
        .get_class_attendance_status(owner_address, 0, 0, student1_address);
    assert(attendance_status, 'not marked');

    start_cheat_caller_address(contract_address, student2_address);
    dispatcher.mark_attendance_for_a_class(owner_address, owner_address, 0, 0);
    stop_cheat_caller_address(contract_address);
    let attendance_status = dispatcher
        .get_class_attendance_status(owner_address, 0, 0, student2_address);
    assert(attendance_status, 'not marked');

    start_cheat_caller_address(contract_address, owner_address);
    dispatcher.batch_certify_students(owner_address, 0);
    let certify_length = dispatcher.get_certified_student_bootcamp_address(owner_address, 0);
    assert(certify_length.len() == 1, 'incorrect array len');
    let get_cert_stat_student1 = dispatcher
        .get_bootcamp_certification_status(owner_address, 0, student1_address);
    assert(get_cert_stat_student1, 'incorrect status');
    let get_cert_stat_student2 = dispatcher
        .get_bootcamp_certification_status(owner_address, 0, student2_address);
    assert(get_cert_stat_student2, 'incorrect status');

    let bootcamps = dispatcher.get_all_org_bootcamps(owner_address);
    let the_bootcamp = bootcamps[0];
    let bootcamp_funds = the_bootcamp.bootcamp_funds;
    assert(*bootcamp_funds == 20, 'Bootcamp funds not correct');
    dispatcher.withdraw_bootcamp_funds(owner_address, 0);
    assert(*bootcamp_funds == 0, 'Funds should be withdrawn');

    stop_cheat_caller_address(contract_address);
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Event::RegistrationApproved(
                        RegistrationApproved {
                            student_address: student1_address_cp, bootcamp_id: 0,
                        },
                    ),
                ),
            ],
        );
}


#[test]
fn test_decline_registration2() {
    //set required addreses
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let mut spy = spy_events();
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let instructor_address: ContractAddress = contract_address_const::<'instructor'>();
    let student_address: ContractAddress = contract_address_const::<'candidate'>();

    // setup dispatcher
    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let bootcamp_name: ByteArray = "web3Bridge bootcamp";
    let org_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    let bootcamp_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    dispatcher.create_org_profile(org_name.clone(), org_ipfs_uri);
    let mut arr_of_instructors: Array<ContractAddress> = array![];
    arr_of_instructors.append(instructor_address);
    dispatcher.add_instructor_to_org(arr_of_instructors, org_name.clone());
    let org = dispatcher.get_org_info(owner_address);
    let org_address: ContractAddress = org.address_of_org;

    let token_uri: ByteArray = "https://dummy_uri.com";
    let token_uri_clone_c: ByteArray = "https://dummy_uri.com";
    let nft_name: ByteArray = "cairo";
    let nft_symb: ByteArray = "CAO";
    dispatcher
        .create_bootcamp(
            org_name, bootcamp_name, token_uri, nft_name, nft_symb, 3, bootcamp_ipfs_uri, 0,
        );
    stop_cheat_caller_address(contract_address);

    let student_address_cp = student_address.clone();
    start_cheat_caller_address(contract_address, student_address_cp);
    dispatcher.register_for_bootcamp(owner_address, 0, token_uri_clone_c);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, owner_address);
    dispatcher.decline_registration(student_address, 0);
    stop_cheat_caller_address(contract_address);

    let all_request = dispatcher.get_all_registration_request(owner_address);
    let status: u8 = *all_request[0].status;
    assert(status == 2, 'not declined');

    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Event::RegistrationDeclined(
                        RegistrationDeclined {
                            student_address: student_address_cp, bootcamp_id: 0,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_decline_registration() {
    //set required addreses
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let mut spy = spy_events();
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let instructor_address: ContractAddress = contract_address_const::<'instructor'>();
    let student_address: ContractAddress = contract_address_const::<'candidate'>();

    // setup dispatcher
    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let bootcamp_name: ByteArray = "web3Bridge bootcamp";
    let org_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    let bootcamp_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    dispatcher.create_org_profile(org_name.clone(), org_ipfs_uri);
    let mut arr_of_instructors: Array<ContractAddress> = array![];
    arr_of_instructors.append(instructor_address);
    dispatcher.add_instructor_to_org(arr_of_instructors, org_name.clone());
    let org = dispatcher.get_org_info(owner_address);
    let org_address: ContractAddress = org.address_of_org;

    let token_uri: ByteArray = "https://dummy_uri.com";
    let token_uri_clone_c: ByteArray = "https://dummy_uri.com";
    let nft_name: ByteArray = "cairo";
    let nft_symb: ByteArray = "CAO";
    dispatcher
        .create_bootcamp(
            org_name, bootcamp_name, token_uri, nft_name, nft_symb, 3, bootcamp_ipfs_uri, 0,
        );
    stop_cheat_caller_address(contract_address);

    let student_address_cp = student_address.clone();
    start_cheat_caller_address(contract_address, student_address_cp);
    dispatcher.register_for_bootcamp(owner_address, 0, token_uri_clone_c);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, owner_address);
    dispatcher.decline_registration(student_address, 0);
    stop_cheat_caller_address(contract_address);

    let all_request = dispatcher.get_all_registration_request(owner_address);
    let status: u8 = *all_request[0].status;
    assert(status == 2, 'not declined');

    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Event::RegistrationDeclined(
                        RegistrationDeclined {
                            student_address: student_address_cp, bootcamp_id: 0,
                        },
                    ),
                ),
            ],
        );
}

#[test]
//@todo Test the registration and the approval of new students.
fn test_sponsor() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let dummy_org = contract_address_const::<'dummy_org'>();
    // let token_addr: ContractAddress = contract_address_const::<
    //     0x04718f5a0Fc34cC1AF16A1cdee98fFB20C31f5cD61D6Ab07201858f4287c938D
    // >();
    let token_addr = contract_address_const::<'token_addr'>();
    let contract_address = deploy_organization_contract("AttenSysOrg", hash, token_addr, dummy_org);
    let contract_owner_address: ContractAddress = contract_address_const::<
        'contract_owner_address',
    >();
    // // set the organization address to the original contract address
// let sponsor_contract_addr = deploy_sponsorship_contract(
//     "AttenSysSponsor", contract_owner_address
// );
// let dispatcherForSponsor = IAttenSysSponsorDispatcher {
//     contract_address: sponsor_contract_addr
// };

    // let owner_address: ContractAddress = contract_address_const::<'owner'>();
// let dispatcher = IAttenSysOrgDispatcher { contract_address };
// start_cheat_caller_address(contract_address, owner_address);
// let org_name: ByteArray = "web3";
// let org_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
// dispatcher.create_org_profile(org_name.clone(), org_ipfs_uri);
// dispatcher.setSponsorShipAddress(sponsor_contract_addr);

    // let dispatcherForToken =IERC20Dispatcher {
//     contract_address: token_addr
// };
// dispatcherForToken.approve(contract_address,100000);

    // dispatcher.sponsor_organization(owner_address, "bsvjsbbsxjkjk", 100000);
}

#[test]
#[should_panic(expected: "no organization created.")]
fn test_when_no_org_address_add_instructor_to_org() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let instructor_address: ContractAddress = contract_address_const::<'instructor'>();

    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, instructor_address);

    let mut arr_of_instructors: Array<ContractAddress> = array![];
    arr_of_instructors.append(instructor_address);
    arr_of_instructors.append(owner_address);
    let org_name: ByteArray = "web3";
    dispatcher.add_instructor_to_org(arr_of_instructors, org_name);
}

#[test]
fn test_sponsor_organization() {
    // Deploy NFT contract
    let owner_address: ContractAddress = contract_address_const::<'contract_owner_address'>();
    let sponsor_address: ContractAddress = contract_address_const::<'sponsor'>();

    // deploy token
    // let initial_supply: u256 = 1_000_000_u256;
    let contract_class = declare("AttenSysToken").unwrap().contract_class();

    let mut constructor_args = ArrayTrait::new();
    // initial_supply.serialize(ref constructor_args);
    sponsor_address.serialize(ref constructor_args);

    let (token_contract_address, _) = ContractClassTrait::deploy(contract_class, @constructor_args)
        .unwrap();

    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let org_contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_contract_address, sponsor_contract_addr,
    );

    //deploy sponsor contract
    let event_contract_address = contract_address_const::<'event_contract_address'>();
    let sponsor_contract_class = declare("AttenSysSponsor").unwrap().contract_class();
    let mut constructor_args = ArrayTrait::new();
    org_contract_address.serialize(ref constructor_args);
    event_contract_address.serialize(ref constructor_args);

    let (sponsor_contract_address, _) = ContractClassTrait::deploy(
        sponsor_contract_class, @constructor_args,
    )
        .unwrap();

    let amount: u256 = 1000_u256;
    let uri: ByteArray = "ipfs://sponsorship-proof";

    // Setup dispatcher
    let dispatcher = IAttenSysOrgDispatcher { contract_address: org_contract_address };

    // Create an organization
    start_cheat_caller_address(org_contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let org_ipfs_uri: ByteArray = "0xorgmetadata";
    dispatcher.setSponsorShipAddress(sponsor_contract_address);
    dispatcher.create_org_profile(org_name.clone(), org_ipfs_uri);
    stop_cheat_caller_address(org_contract_address);

    //approve contract to spend token
    let token_dispatcher = ERC20ABIDispatcher { contract_address: token_contract_address };
    start_cheat_caller_address(token_contract_address, sponsor_address);
    token_dispatcher.approve(sponsor_contract_address, amount);
    stop_cheat_caller_address(token_contract_address);

    let allowance = token_dispatcher.allowance(sponsor_address, sponsor_contract_address);
    let sponsor_bal = token_dispatcher.balance_of(sponsor_address);

    // Sponsor the organization
    let org = dispatcher.get_org_info(owner_address);
    let org_address: ContractAddress = org.address_of_org;
    start_cheat_caller_address(org_contract_address, sponsor_address);
    dispatcher.sponsor_organization(org_address, uri.clone(), amount);
    stop_cheat_caller_address(org_contract_address);

    // Verify sponsorship balance updated
    let org_balance = dispatcher.get_org_sponsorship_balance(owner_address);
    let sponsorship_contract_balance = token_dispatcher.balance_of(sponsor_contract_address);

    assert(org_balance == amount, 'wrong Org sponsorship bal');
    assert(sponsorship_contract_balance == amount, 'Wrong Sponsor contract bal')
}

#[test]
fn test_withdraw_sponsorship_fund() {
    // Deploy NFT contract
    let owner_address: ContractAddress = contract_address_const::<'contract_owner_address'>();
    let sponsor_address: ContractAddress = contract_address_const::<'sponsor'>();

    // deploy token
    // let initial_supply: u256 = 1_000_000_u256;
    let contract_class = declare("AttenSysToken").unwrap().contract_class();

    let mut constructor_args = ArrayTrait::new();
    // initial_supply.serialize(ref constructor_args);
    sponsor_address.serialize(ref constructor_args);

    let (token_contract_address, _) = ContractClassTrait::deploy(contract_class, @constructor_args)
        .unwrap();

    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let org_contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_contract_address, sponsor_contract_addr,
    );

    //deploy sponsor contract
    let event_contract_address = contract_address_const::<'event_contract_address'>();
    let sponsor_contract_class = declare("AttenSysSponsor").unwrap().contract_class();
    let mut constructor_args = ArrayTrait::new();
    org_contract_address.serialize(ref constructor_args);
    event_contract_address.serialize(ref constructor_args);

    let (sponsor_contract_address, _) = ContractClassTrait::deploy(
        sponsor_contract_class, @constructor_args,
    )
        .unwrap();

    let amount: u256 = 1000_u256;
    let uri: ByteArray = "ipfs://sponsorship-proof";

    // Setup dispatcher
    let dispatcher = IAttenSysOrgDispatcher { contract_address: org_contract_address };

    // Create an organization
    start_cheat_caller_address(org_contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let org_ipfs_uri: ByteArray = "0xorgmetadata";
    dispatcher.setSponsorShipAddress(sponsor_contract_address);
    dispatcher.create_org_profile(org_name.clone(), org_ipfs_uri);
    let tier = dispatcher.get_tier(owner_address);
    assert(tier == Tier::Free, 'wrong tier');
    // Remove println since Debug trait is not implemented
    stop_cheat_caller_address(org_contract_address);

    //approve contract to spend token
    let token_dispatcher = ERC20ABIDispatcher { contract_address: token_contract_address };
    start_cheat_caller_address(token_contract_address, sponsor_address);
    token_dispatcher.approve(sponsor_contract_address, amount);
    stop_cheat_caller_address(token_contract_address);

    let allowance = token_dispatcher.allowance(sponsor_address, sponsor_contract_address);
    let sponsor_bal = token_dispatcher.balance_of(sponsor_address);

    // Sponsor the organization
    let org = dispatcher.get_org_info(owner_address);
    let org_address: ContractAddress = org.address_of_org;
    start_cheat_caller_address(org_contract_address, sponsor_address);
    dispatcher.sponsor_organization(org_address, uri.clone(), amount);
    stop_cheat_caller_address(org_contract_address);

    // Verify sponsorship balance updated
    let org_balance = dispatcher.get_org_sponsorship_balance(owner_address);
    let sponsorship_contract_balance = token_dispatcher.balance_of(sponsor_contract_address);

    assert(org_balance == amount, 'wrong Org sponsorship bal');
    assert(sponsorship_contract_balance == amount, 'Wrong Sponsor contract bal');

    start_cheat_caller_address(org_contract_address, org_address);
    dispatcher.withdraw_sponsorship_fund(amount);
    stop_cheat_caller_address(org_contract_address);

    // Verify balances after withdrawal
    let org_balance_after = dispatcher.get_org_sponsorship_balance(owner_address);
    let sponsorship_contract_balance_after = token_dispatcher.balance_of(sponsor_contract_address);
    assert(org_balance_after == 0, 'sponsor bal not updated');
    assert(sponsorship_contract_balance_after == 0, 'wrong Sponsor contr bal');
}

#[test]
#[should_panic(expected: "not an organization")]
fn test_withdraw_sponsorship_fund_unauthorized_caller_should_panic() {
    // Deploy NFT contract
    let owner_address: ContractAddress = contract_address_const::<'contract_owner_address'>();
    let sponsor_address: ContractAddress = contract_address_const::<'sponsor'>();
    let unauthorized_caller: ContractAddress = contract_address_const::<'unauthorized_caller'>();

    // deploy token
    // let initial_supply: u256 = 1_000_000_u256;
    let contract_class = declare("AttenSysToken").unwrap().contract_class();

    let mut constructor_args = ArrayTrait::new();
    // initial_supply.serialize(ref constructor_args);
    sponsor_address.serialize(ref constructor_args);

    let (token_contract_address, _) = ContractClassTrait::deploy(contract_class, @constructor_args)
        .unwrap();

    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let org_contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_contract_address, sponsor_contract_addr,
    );

    //deploy sponsor contract
    let event_contract_address = contract_address_const::<'event_contract_address'>();
    let sponsor_contract_class = declare("AttenSysSponsor").unwrap().contract_class();
    let mut constructor_args = ArrayTrait::new();
    org_contract_address.serialize(ref constructor_args);
    event_contract_address.serialize(ref constructor_args);

    let (sponsor_contract_address, _) = ContractClassTrait::deploy(
        sponsor_contract_class, @constructor_args,
    )
        .unwrap();

    let amount: u256 = 1000_u256;
    let uri: ByteArray = "ipfs://sponsorship-proof";

    // Setup dispatcher
    let dispatcher = IAttenSysOrgDispatcher { contract_address: org_contract_address };

    // Create an organization
    start_cheat_caller_address(org_contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let org_ipfs_uri: ByteArray = "0xorgmetadata";
    dispatcher.setSponsorShipAddress(sponsor_contract_address);
    dispatcher.create_org_profile(org_name.clone(), org_ipfs_uri);
    stop_cheat_caller_address(org_contract_address);

    //approve contract to spend token
    let token_dispatcher = ERC20ABIDispatcher { contract_address: token_contract_address };
    start_cheat_caller_address(token_contract_address, sponsor_address);
    token_dispatcher.approve(sponsor_contract_address, amount);
    stop_cheat_caller_address(token_contract_address);

    let allowance = token_dispatcher.allowance(sponsor_address, sponsor_contract_address);
    let sponsor_bal = token_dispatcher.balance_of(sponsor_address);

    // Sponsor the organization
    let org = dispatcher.get_org_info(owner_address);
    let org_address: ContractAddress = org.address_of_org;
    start_cheat_caller_address(org_contract_address, sponsor_address);
    dispatcher.sponsor_organization(org_address, uri.clone(), amount);
    stop_cheat_caller_address(org_contract_address);

    // Verify sponsorship balance updated
    let org_balance = dispatcher.get_org_sponsorship_balance(owner_address);
    let sponsorship_contract_balance = token_dispatcher.balance_of(sponsor_contract_address);

    assert(org_balance == amount, 'wrong Org sponsorship bal');
    assert(sponsorship_contract_balance == amount, 'Wrong Sponsor contract bal');

    start_cheat_caller_address(org_contract_address, unauthorized_caller);
    dispatcher.withdraw_sponsorship_fund(amount);
    stop_cheat_caller_address(org_contract_address);

    // Verify balances after withdrawal
    let org_balance_after = dispatcher.get_org_sponsorship_balance(owner_address);
    let sponsorship_contract_balance_after = token_dispatcher.balance_of(sponsor_contract_address);
    assert(org_balance_after == 0, 'sponsor bal not updated');
    assert(sponsorship_contract_balance_after == 0, 'wrong Sponsor contr bal');
}
#[test]
fn test_transfer_org_admin() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let admin: ContractAddress = contract_address_const::<'contract_owner_address'>();
    let new_admin: ContractAddress = contract_address_const::<'new_admin'>();
    // setup dispatcher
    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    assert(dispatcher.get_admin() == admin, 'wrong admin');

    start_cheat_caller_address(contract_address, admin);

    dispatcher.transfer_admin(new_admin);
    assert(dispatcher.get_new_admin() == new_admin, 'wrong intended admin');

    stop_cheat_caller_address(contract_address)
}

#[test]
fn test_claim_org_admin() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let admin: ContractAddress = contract_address_const::<'contract_owner_address'>();
    let new_admin: ContractAddress = contract_address_const::<'new_admin'>();
    // setup dispatcher
    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    assert(dispatcher.get_admin() == admin, 'wrong admin');

    // Admin transfers admin rights to new_admin
    start_cheat_caller_address(contract_address, admin);
    dispatcher.transfer_admin(new_admin);
    assert(dispatcher.get_new_admin() == new_admin, 'wrong intended admin');
    stop_cheat_caller_address(contract_address);

    // New admin claims admin rights
    start_cheat_caller_address(contract_address, new_admin);
    dispatcher.claim_admin_ownership();
    assert(dispatcher.get_admin() == new_admin, 'admin claim failed');
    assert(dispatcher.get_new_admin() == contract_address_const::<0>(), 'admin claim failed');
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'unauthorized caller')]
fn test_transfer_org_admin_should_panic_for_wrong_admin() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let invalid_admin: ContractAddress = contract_address_const::<'invalid_admin'>();
    let new_admin: ContractAddress = contract_address_const::<'new_admin'>();
    // setup dispatcher
    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    // Wrong admin transfers admin rights to new_admin: should revert
    start_cheat_caller_address(contract_address, invalid_admin);
    dispatcher.transfer_admin(new_admin);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'unauthorized caller')]
fn test_claim_org_admin_should_panic_for_wrong_new_admin() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let admin: ContractAddress = contract_address_const::<'contract_owner_address'>();
    let new_admin: ContractAddress = contract_address_const::<'new_admin'>();
    let wrong_new_admin: ContractAddress = contract_address_const::<'wrong_new_admin'>();
    // setup dispatcher
    let dispatcher = IAttenSysOrgDispatcher { contract_address };

    assert(dispatcher.get_admin() == admin, 'wrong admin');

    // Admin transfers admin rights to new_admin
    start_cheat_caller_address(contract_address, admin);
    dispatcher.transfer_admin(new_admin);
    stop_cheat_caller_address(contract_address);

    // Wrong new admin claims admin rights: should panic
    start_cheat_caller_address(contract_address, wrong_new_admin);
    dispatcher.claim_admin_ownership();
    stop_cheat_caller_address(contract_address);
}

////////////////////// Suspension Test Cases /////////////////////////////

#[test]
fn test_suspend_org() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();

    let mut spy = spy_events();

    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();

    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let owner_address: ContractAddress = contract_address_const::<'owner'>();

    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let org_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";

    let org_name_copy = org_name.clone();
    dispatcher.create_org_profile(org_name, org_ipfs_uri);

    stop_cheat_caller_address(contract_address);
    let contract_owner_address: ContractAddress = contract_address_const::<
        'contract_owner_address',
    >();

    start_cheat_caller_address(contract_address, contract_owner_address);
    dispatcher.suspend_organization(owner_address, true);

    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Event::OrganizationSuspended(
                        OrganizationSuspended {
                            org_contract_address: owner_address,
                            org_name: org_name_copy,
                            suspended: true,
                        },
                    ),
                ),
            ],
        );

    /// assert the getter function return the correct state.
    let is_suspended = dispatcher.is_org_suspended(owner_address);
    assert_eq!(is_suspended, true);
}

#[test]
fn test_unsuspend_org() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();

    let mut spy = spy_events();

    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();

    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let owner_address: ContractAddress = contract_address_const::<'owner'>();

    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let org_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";

    let org_name_copy = org_name.clone();
    dispatcher.create_org_profile(org_name, org_ipfs_uri);

    stop_cheat_caller_address(contract_address);

    let contract_owner_address: ContractAddress = contract_address_const::<
        'contract_owner_address',
    >();

    start_cheat_caller_address(contract_address, contract_owner_address);
    dispatcher.suspend_organization(owner_address, true);

    /// assert the getter function return the correct state.
    let is_suspended = dispatcher.is_org_suspended(owner_address);
    assert_eq!(is_suspended, true);

    dispatcher.suspend_organization(owner_address, false);

    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Event::OrganizationSuspended(
                        OrganizationSuspended {
                            org_contract_address: owner_address,
                            org_name: org_name_copy,
                            suspended: false,
                        },
                    ),
                ),
            ],
        );
    /// assert the getter function return the correct state.
    let is_suspended = dispatcher.is_org_suspended(owner_address);
    assert_eq!(is_suspended, false);
}
#[test]
#[should_panic(expected: 'Not admin')]
fn test_suspend_org_panic() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();

    let mut spy = spy_events();

    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();

    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let owner_address: ContractAddress = contract_address_const::<'owner'>();

    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let org_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";

    let org_name_copy = org_name.clone();
    dispatcher.create_org_profile(org_name, org_ipfs_uri);

    stop_cheat_caller_address(contract_address);
    // non admin try to call suspenssion function
    dispatcher.suspend_organization(owner_address, true);
}

#[test]
fn test_suspend_bootcamp_for_org() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let instructor_address: ContractAddress = contract_address_const::<'instructor'>();

    let mut spy = spy_events();

    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let org_name_cp = org_name.clone();
    let bootcamp_name: ByteArray = "web3Bridge bootcamp";
    let bootcamp_name_cp = bootcamp_name.clone();
    let org_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    let bootcamp_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    let bootcamp_ipfs_uri_cp = bootcamp_ipfs_uri.clone();
    dispatcher.create_org_profile(org_name.clone(), org_ipfs_uri);
    let mut arr_of_instructors: Array<ContractAddress> = array![];
    arr_of_instructors.append(instructor_address);
    dispatcher.add_instructor_to_org(arr_of_instructors, org_name.clone());
    let org = dispatcher.get_org_info(owner_address);
    assert_eq!(org.number_of_instructors, 2);

    let token_uri: ByteArray = "https://dummy_uri.com";
    let token_uri_cp = token_uri.clone();
    let nft_name: ByteArray = "cairo";
    let nft_name_cp = nft_name.clone();
    let nft_symb: ByteArray = "CAO";
    let nft_symb_cp = nft_symb.clone();

    dispatcher
        .create_bootcamp(
            org_name, bootcamp_name, token_uri, nft_name, nft_symb, 3, bootcamp_ipfs_uri, 0,
        );
    let updatedOrg = dispatcher.get_org_info(owner_address);
    assert_eq!(updatedOrg.number_of_all_bootcamps, 1);
    assert_eq!(updatedOrg.number_of_all_classes, 3);
    stop_cheat_caller_address(contract_address);

    let contract_owner_address: ContractAddress = contract_address_const::<
        'contract_owner_address',
    >();

    start_cheat_caller_address(contract_address, contract_owner_address);
    // suspend bootcamp
    dispatcher.suspend_org_bootcamp(owner_address, 0, true);

    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Event::BootCampSuspended(
                        BootCampSuspended {
                            org_contract_address: owner_address,
                            bootcamp_id: 0,
                            bootcamp_name: bootcamp_name_cp,
                            suspended: true,
                        },
                    ),
                ),
            ],
        );
    let is_suspended = dispatcher.is_bootcamp_suspended(owner_address, 0);
    assert_eq!(is_suspended, true);
}

#[test]
fn test_unsuspend_bootcamp_for_org() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let instructor_address: ContractAddress = contract_address_const::<'instructor'>();

    let mut spy = spy_events();

    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let org_name_cp = org_name.clone();
    let bootcamp_name: ByteArray = "web3Bridge bootcamp";
    let bootcamp_name_cp = bootcamp_name.clone();
    let org_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    let bootcamp_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    let bootcamp_ipfs_uri_cp = bootcamp_ipfs_uri.clone();
    dispatcher.create_org_profile(org_name.clone(), org_ipfs_uri);
    let mut arr_of_instructors: Array<ContractAddress> = array![];
    arr_of_instructors.append(instructor_address);
    dispatcher.add_instructor_to_org(arr_of_instructors, org_name.clone());
    let org = dispatcher.get_org_info(owner_address);
    assert_eq!(org.number_of_instructors, 2);

    let token_uri: ByteArray = "https://dummy_uri.com";
    let token_uri_cp = token_uri.clone();
    let nft_name: ByteArray = "cairo";
    let nft_name_cp = nft_name.clone();
    let nft_symb: ByteArray = "CAO";
    let nft_symb_cp = nft_symb.clone();

    dispatcher
        .create_bootcamp(
            org_name, bootcamp_name, token_uri, nft_name, nft_symb, 3, bootcamp_ipfs_uri, 0,
        );
    let updatedOrg = dispatcher.get_org_info(owner_address);
    assert_eq!(updatedOrg.number_of_all_bootcamps, 1);
    assert_eq!(updatedOrg.number_of_all_classes, 3);
    stop_cheat_caller_address(contract_address);

    let contract_owner_address: ContractAddress = contract_address_const::<
        'contract_owner_address',
    >();

    start_cheat_caller_address(contract_address, contract_owner_address);
    // suspend bootcamp
    dispatcher.suspend_org_bootcamp(owner_address, 0, true);

    let is_suspended = dispatcher.is_bootcamp_suspended(owner_address, 0);
    assert_eq!(is_suspended, true);
    // unsuspend bootcamp
    dispatcher.suspend_org_bootcamp(owner_address, 0, false);

    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Event::BootCampSuspended(
                        BootCampSuspended {
                            org_contract_address: owner_address,
                            bootcamp_id: 0,
                            bootcamp_name: bootcamp_name_cp,
                            suspended: false,
                        },
                    ),
                ),
            ],
        );
    let is_suspended = dispatcher.is_bootcamp_suspended(owner_address, 0);
    assert_eq!(is_suspended, false);
}

#[test]
#[should_panic(expected: 'Not admin')]
fn test_suspend_bootcamp_for_org_panic() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let instructor_address: ContractAddress = contract_address_const::<'instructor'>();

    let mut spy = spy_events();

    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let org_name_cp = org_name.clone();
    let bootcamp_name: ByteArray = "web3Bridge bootcamp";
    let bootcamp_name_cp = bootcamp_name.clone();
    let org_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    let bootcamp_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";
    let bootcamp_ipfs_uri_cp = bootcamp_ipfs_uri.clone();
    dispatcher.create_org_profile(org_name.clone(), org_ipfs_uri);
    let mut arr_of_instructors: Array<ContractAddress> = array![];
    arr_of_instructors.append(instructor_address);
    dispatcher.add_instructor_to_org(arr_of_instructors, org_name.clone());
    let org = dispatcher.get_org_info(owner_address);
    assert_eq!(org.number_of_instructors, 2);

    let token_uri: ByteArray = "https://dummy_uri.com";
    let token_uri_cp = token_uri.clone();
    let nft_name: ByteArray = "cairo";
    let nft_name_cp = nft_name.clone();
    let nft_symb: ByteArray = "CAO";
    let nft_symb_cp = nft_symb.clone();

    dispatcher
        .create_bootcamp(
            org_name, bootcamp_name, token_uri, nft_name, nft_symb, 3, bootcamp_ipfs_uri, 0,
        );
    let updatedOrg = dispatcher.get_org_info(owner_address);
    assert_eq!(updatedOrg.number_of_all_bootcamps, 1);
    assert_eq!(updatedOrg.number_of_all_classes, 3);
    stop_cheat_caller_address(contract_address);

    // non admin try to call suspenssion function
    dispatcher.suspend_org_bootcamp(owner_address, 0, true);
}

// --- REMOVE BOOTCAMP TESTS ---
#[test]
fn test_remove_bootcamp_success() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, owner_address);
    dispatcher.create_org_profile("web3", "ipfs://org");
    dispatcher
        .create_bootcamp("web3", "bootcamp1", "nft_uri", "NFT", "NFTSYM", 1, "ipfs://bootcamp1", 0);
    let org = dispatcher.get_org_info(owner_address);
    assert_eq!(org.number_of_all_bootcamps, 1);
    dispatcher.remove_bootcamp(0);
    let org = dispatcher.get_org_info(owner_address);
    assert_eq!(org.number_of_all_bootcamps, 0);
    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Event::BootcampRemoved(
                        BootcampRemoved {
                            org_contract_address: owner_address,
                            bootcamp_id: 0,
                            bootcamp_name: "bootcamp1",
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic]
fn test_remove_bootcamp_non_owner() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let not_owner: ContractAddress = contract_address_const::<'not_owner'>();
    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    dispatcher.create_org_profile("web3", "ipfs://org");
    dispatcher
        .create_bootcamp("web3", "bootcamp1", "nft_uri", "NFT", "NFTSYM", 1, "ipfs://bootcamp1", 0);
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, not_owner);
    dispatcher.remove_bootcamp(0);
}

#[test]
#[should_panic(expected: 'Has participants')]
fn test_remove_bootcamp_with_participants() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let student_address: ContractAddress = contract_address_const::<'candidate'>();
    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    dispatcher.create_org_profile("web3", "ipfs://org");
    dispatcher
        .create_bootcamp("web3", "bootcamp1", "nft_uri", "NFT", "NFTSYM", 1, "ipfs://bootcamp1", 0);
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, student_address);
    dispatcher.register_for_bootcamp(owner_address, 0, "ipfs://student");
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, owner_address);
    dispatcher.approve_registration(student_address, 0);
    dispatcher.remove_bootcamp(0);
}

#[test]
fn test_remove_bootcamp_state_cleanup() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    dispatcher.create_org_profile("web3", "ipfs://org");
    dispatcher
        .create_bootcamp("web3", "bootcamp1", "nft_uri", "NFT", "NFTSYM", 1, "ipfs://bootcamp1", 0);
    dispatcher.add_active_meet_link("meet", 0, false, owner_address);
    dispatcher.remove_bootcamp(0);
    // Should not panic, state should be cleaned
    let org = dispatcher.get_org_info(owner_address);
    assert_eq!(org.number_of_all_bootcamps, 0);
}

#[test]
#[should_panic]
fn test_remove_non_existent_bootcamp() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    dispatcher.create_org_profile("web3", "ipfs://org");
    dispatcher.remove_bootcamp(0);
}

// Additional edge and concurrency tests can be added as needed, e.g. for expiration, pending
// payments, etc.

///// Tier price tests /////

#[test]
#[should_panic(expected: 'Not admin')]
fn test_setting_tier_price_panic() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let owner_address: ContractAddress = contract_address_const::<'owner'>();
    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    // non admin try to call setting tier price function
    dispatcher.set_tier_price(0, 100);
}

#[test]
fn test_setting_tier_price() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();
    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();
    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    let mut spy = spy_events();
    start_cheat_caller_address(contract_address, dispatcher.get_admin());
    // admin calls setting tier price function to be successful
    dispatcher.set_tier_price(0, 100);
    let tier_price = dispatcher.get_tier_price(0);
    assert_eq!(tier_price, 100);
    stop_cheat_caller_address(contract_address);
    spy
        .assert_emitted(
            @array![(contract_address, Event::SetTierPrice(SetTierPrice { tier: 0, price: 100 }))],
        );
}


#[test]
fn test_change_tier_for_org() {
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");
    let token_addr = contract_address_const::<'new_owner'>();

    let mut spy = spy_events();

    let sponsor_contract_addr = contract_address_const::<'sponsor_contract_addr'>();

    let contract_address = deploy_organization_contract(
        "AttenSysOrg", hash, token_addr, sponsor_contract_addr,
    );
    let owner_address: ContractAddress = contract_address_const::<'owner'>();

    let dispatcher = IAttenSysOrgDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner_address);
    let org_name: ByteArray = "web3";
    let org_ipfs_uri: ByteArray = "0xnsbsmmfbnakkdbbfjsgbdmmcjjmdnweb3";

    let org_name_copy = org_name.clone();
    dispatcher.create_org_profile(org_name, org_ipfs_uri);

    stop_cheat_caller_address(contract_address);
    let contract_owner_address: ContractAddress = contract_address_const::<
        'contract_owner_address',
    >();

    start_cheat_caller_address(contract_address, owner_address);
    dispatcher.change_tier(owner_address, Tier::Premium);

    spy
        .assert_emitted(
            @array![
                (
                    contract_address,
                    Event::ChangeTier(
                        ChangeTier { org_address: owner_address, new_tier: Tier::Premium },
                    ),
                ),
            ],
        );

    let tier = dispatcher.get_tier(owner_address);
    assert(tier == Tier::Premium, 'wrong tier');
}

