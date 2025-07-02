use attendsys::contracts::event::AttenSysEvent::{
    IAttenSysEventDispatcher, IAttenSysEventDispatcherTrait,
};
use attendsys::contracts::sponsor::AttenSysSponsor::{
    AttenSysSponsor, IAttenSysSponsorDispatcher, IAttenSysSponsorDispatcherTrait,
};
use attendsys::contracts::token::AttenSysToken;
// use openzeppelin::token::erc20::interface::{IERC20MixinDispatcher, IERC20MixinDispatcherTrait};
use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_block_timestamp_global, start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ClassHash, ContractAddress, contract_address_const};


// Helper function to deploy contracts
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
fn test_successful_sponsor_event_flow() {
    let owner_address: ContractAddress = contract_address_const::<'admin'>();
    let sponsor_address: ContractAddress = contract_address_const::<'sponsor'>();

    let sponsor_amount: u256 = 1000_u256;
    let sponsor_uri: ByteArray = "ipfs://event-sponsor";

    // deploy the token
    // let initial_supply: u256 = 1_000_000_u256;
    let token_contract_class = declare("AttenSysToken").unwrap().contract_class();
    let mut constructor_args: Array<felt252> = ArrayTrait::new();
    // initial_supply.serialize(ref constructor_args);
    sponsor_address.serialize(ref constructor_args);
    let (token_contract_address, _) = ContractClassTrait::deploy(
        token_contract_class, @constructor_args,
    )
        .unwrap();

    // deploy the nft contract
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");

    // deploy the event contract
    let temp_sponsor_contract_address = contract_address_const::<'sponsor_contract_addr'>();
    let event_contract_address = deploy_event_contract(
        "AttenSysEvent", hash, token_contract_address, temp_sponsor_contract_address,
    );

    // //deploy the sponsor contract
    let org_contract_address = contract_address_const::<'org_contract_address'>();
    let sponsor_contract_class = declare("AttenSysSponsor").unwrap().contract_class();
    let mut constructor_args: Array<felt252> = ArrayTrait::new();
    org_contract_address.serialize(ref constructor_args);
    event_contract_address.serialize(ref constructor_args);
    let (sponsor_contract_address, _) = ContractClassTrait::deploy(
        sponsor_contract_class, @constructor_args,
    )
        .unwrap();

    // create an event
    let event_dispatcher = IAttenSysEventDispatcher { contract_address: event_contract_address };
    let event_name: ByteArray = "starknet-builders-workshop";
    let event_ipfs_uri: ByteArray = "ipfs://event-uri";
    let event_owner_address: ContractAddress = contract_address_const::<'event_owner'>();
    let token_uri: ByteArray = "https://dummy_uri.com/your_id";
    let nft_name: ByteArray = "ODBuild";
    let nft_symb: ByteArray = "ODB";

    start_cheat_caller_address(event_contract_address, owner_address);
    event_dispatcher.set_sponsorship_contract(sponsor_contract_address);
    event_dispatcher
        .create_event(
            event_owner_address,
            event_name.clone(),
            token_uri,
            nft_name,
            nft_symb,
            2238493,
            32989989,
            1,
            event_ipfs_uri.clone(),
            0,
        );
    stop_cheat_caller_address(event_contract_address);

    //approve contract to spend token
    let token_dispatcher = ERC20ABIDispatcher { contract_address: token_contract_address };
    start_cheat_caller_address(token_contract_address, sponsor_address);
    token_dispatcher.approve(sponsor_contract_address, sponsor_amount);
    stop_cheat_caller_address(token_contract_address);

    // Sponsor the created event
    let created_event = event_dispatcher.get_event_details(1);
    let created_event_address: ContractAddress = created_event.event_organizer;

    // Confirm event sponsorship balance is initially empty
    let initial_event_balance = event_dispatcher
        .get_event_sponsorship_balance(created_event_address);
    assert(initial_event_balance == 0, 'Wrong event balance');

    start_cheat_caller_address(event_contract_address, sponsor_address);
    event_dispatcher.sponsor_event(1, sponsor_amount, sponsor_uri.clone());
    stop_cheat_caller_address(event_contract_address);

    // Check event balance was updated
    let latest_event_balance = event_dispatcher
        .get_event_sponsorship_balance(created_event_address);
    assert(latest_event_balance == sponsor_amount, 'Wrong event balance');

    // Check tokens were transferred to sponsorhip contract
    let sponsor_balance = token_dispatcher.balanceOf(sponsor_contract_address);
    assert!(sponsor_balance == sponsor_amount, "Inaccurate sponsor balance");
}

#[test]
fn test_successful_withdrawal_by_event_creator() {
    let owner_address: ContractAddress = contract_address_const::<'admin'>();
    let sponsor_address: ContractAddress = contract_address_const::<'sponsor'>();

    let sponsor_amount: u256 = 1000_u256;
    let sponsor_uri: ByteArray = "ipfs://event-sponsor";

    // deploy the token
    // let initial_supply: u256 = 1_000_000_u256;
    let token_contract_class = declare("AttenSysToken").unwrap().contract_class();
    let mut constructor_args: Array<felt252> = ArrayTrait::new();
    // initial_supply.serialize(ref constructor_args);
    sponsor_address.serialize(ref constructor_args);
    let (token_contract_address, _) = ContractClassTrait::deploy(
        token_contract_class, @constructor_args,
    )
        .unwrap();

    // deploy the nft contract
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");

    // deploy the event contract
    let temp_sponsor_contract_address = contract_address_const::<'sponsor_contract_addr'>();
    let event_contract_address = deploy_event_contract(
        "AttenSysEvent", hash, token_contract_address, temp_sponsor_contract_address,
    );

    // //deploy the sponsor contract
    let org_contract_address = contract_address_const::<'org_contract_address'>();
    let sponsor_contract_class = declare("AttenSysSponsor").unwrap().contract_class();
    let mut constructor_args: Array<felt252> = ArrayTrait::new();
    org_contract_address.serialize(ref constructor_args);
    event_contract_address.serialize(ref constructor_args);
    let (sponsor_contract_address, _) = ContractClassTrait::deploy(
        sponsor_contract_class, @constructor_args,
    )
        .unwrap();

    // create an event
    let event_dispatcher = IAttenSysEventDispatcher { contract_address: event_contract_address };
    let event_name: ByteArray = "starknet-builders-workshop";
    let event_ipfs_uri: ByteArray = "ipfs://event-uri";
    let event_owner_address: ContractAddress = contract_address_const::<'event_owner'>();
    let token_uri: ByteArray = "https://dummy_uri.com/your_id";
    let nft_name: ByteArray = "ODBuild";
    let nft_symb: ByteArray = "ODB";

    start_cheat_caller_address(event_contract_address, owner_address);
    event_dispatcher.set_sponsorship_contract(sponsor_contract_address);
    event_dispatcher
        .create_event(
            event_owner_address,
            event_name.clone(),
            token_uri,
            nft_name,
            nft_symb,
            2238493,
            32989989,
            1,
            event_ipfs_uri.clone(),
            0,
        );
    stop_cheat_caller_address(event_contract_address);

    //approve contract to spend token
    let token_dispatcher = ERC20ABIDispatcher { contract_address: token_contract_address };
    start_cheat_caller_address(token_contract_address, sponsor_address);
    token_dispatcher.approve(sponsor_contract_address, sponsor_amount);
    stop_cheat_caller_address(token_contract_address);

    // Sponsor the created event
    let created_event = event_dispatcher.get_event_details(1);
    let created_event_address: ContractAddress = created_event.event_organizer;

    // Confirm event sponsorship balance is initially empty
    let initial_event_balance = event_dispatcher
        .get_event_sponsorship_balance(created_event_address);
    assert(initial_event_balance == 0, 'Wrong event balance');

    start_cheat_caller_address(event_contract_address, sponsor_address);
    event_dispatcher.sponsor_event(1, sponsor_amount, sponsor_uri.clone());
    stop_cheat_caller_address(event_contract_address);

    // Check event balance was updated
    let latest_event_balance = event_dispatcher
        .get_event_sponsorship_balance(created_event_address);
    assert(latest_event_balance == sponsor_amount, 'Wrong event balance');

    // Check tokens were transferred to sponsorhip contract
    let sponsor_balance = token_dispatcher.balanceOf(sponsor_contract_address);
    assert!(sponsor_balance == sponsor_amount, "Inaccurate sponsor balance");

    start_cheat_caller_address(event_contract_address, created_event_address);
    event_dispatcher.withdraw_sponsorship_funds(sponsor_amount);
    stop_cheat_caller_address(event_contract_address);

    // Check balances after successful withdrawal
    let event_balance_withdrawn = event_dispatcher
        .get_event_sponsorship_balance(created_event_address);
    let sponsorship_contract_withdrawn = token_dispatcher.balanceOf(sponsor_contract_address);
    assert(event_balance_withdrawn == 0, 'Wrong event balance withdrawn');
    assert(sponsorship_contract_withdrawn == 0, 'Wrong sponsor balance');
}

#[test]
#[should_panic(expected: ('No such event',))]
fn test_unauthorized_event_withdrawal() {
    let unauthorized = contract_address_const::<'unauthorized'>();
    let owner_address: ContractAddress = contract_address_const::<'admin'>();
    let sponsor_address: ContractAddress = contract_address_const::<'sponsor'>();

    let sponsor_amount: u256 = 1000_u256;
    let sponsor_uri: ByteArray = "ipfs://event-sponsor";

    // deploy the token
    // let initial_supply: u256 = 1_000_000_u256;
    let token_contract_class = declare("AttenSysToken").unwrap().contract_class();
    let mut constructor_args: Array<felt252> = ArrayTrait::new();
    // initial_supply.serialize(ref constructor_args);
    sponsor_address.serialize(ref constructor_args);
    let (token_contract_address, _) = ContractClassTrait::deploy(
        token_contract_class, @constructor_args,
    )
        .unwrap();
    // deploy the nft contract
    let (_nft_contract_address, hash) = deploy_nft_contract("AttenSysNft");

    // deploy the event contract
    let temp_sponsor_contract_address = contract_address_const::<'sponsor_contract_addr'>();
    let event_contract_address = deploy_event_contract(
        "AttenSysEvent", hash, token_contract_address, temp_sponsor_contract_address,
    );

    // //deploy the sponsor contract
    let org_contract_address = contract_address_const::<'org_contract_address'>();
    let sponsor_contract_class = declare("AttenSysSponsor").unwrap().contract_class();
    let mut constructor_args: Array<felt252> = ArrayTrait::new();
    org_contract_address.serialize(ref constructor_args);
    event_contract_address.serialize(ref constructor_args);
    let (sponsor_contract_address, _) = ContractClassTrait::deploy(
        sponsor_contract_class, @constructor_args,
    )
        .unwrap();

    // create an event
    let event_dispatcher = IAttenSysEventDispatcher { contract_address: event_contract_address };
    let event_name: ByteArray = "starknet-builders-workshop";
    let event_ipfs_uri: ByteArray = "ipfs://event-uri";
    let event_owner_address: ContractAddress = contract_address_const::<'event_owner'>();
    let token_uri: ByteArray = "https://dummy_uri.com/your_id";
    let nft_name: ByteArray = "ODBuild";
    let nft_symb: ByteArray = "ODB";

    start_cheat_caller_address(event_contract_address, owner_address);
    event_dispatcher.set_sponsorship_contract(sponsor_contract_address);
    event_dispatcher
        .create_event(
            event_owner_address,
            event_name.clone(),
            token_uri,
            nft_name,
            nft_symb,
            2238493,
            32989989,
            1,
            event_ipfs_uri.clone(),
            0,
        );
    stop_cheat_caller_address(event_contract_address);

    //approve contract to spend token
    let token_dispatcher = ERC20ABIDispatcher { contract_address: token_contract_address };
    start_cheat_caller_address(token_contract_address, sponsor_address);
    token_dispatcher.approve(sponsor_contract_address, sponsor_amount);
    stop_cheat_caller_address(token_contract_address);

    // Sponsor the created event
    let created_event = event_dispatcher.get_event_details(1);
    let created_event_address: ContractAddress = created_event.event_organizer;

    // Confirm event sponsorship balance is initially empty
    let initial_event_balance = event_dispatcher
        .get_event_sponsorship_balance(created_event_address);
    assert(initial_event_balance == 0, 'Wrong event balance');

    start_cheat_caller_address(event_contract_address, sponsor_address);
    event_dispatcher.sponsor_event(1, sponsor_amount, sponsor_uri.clone());
    stop_cheat_caller_address(event_contract_address);

    // Check event balance was updated
    let latest_event_balance = event_dispatcher
        .get_event_sponsorship_balance(created_event_address);
    assert(latest_event_balance == sponsor_amount, 'Wrong event balance');

    // Check tokens were transferred to sponsorhip contract
    let sponsor_balance = token_dispatcher.balanceOf(sponsor_contract_address);
    assert!(sponsor_balance == sponsor_amount, "Inaccurate sponsor balance");

    start_cheat_caller_address(event_contract_address, unauthorized);
    event_dispatcher.withdraw_sponsorship_funds(sponsor_amount);
    stop_cheat_caller_address(event_contract_address);
}
