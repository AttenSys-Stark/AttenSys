use attendsys::contracts::course::AttenSysCourse::{
    IAttenSysCourseDispatcher, IAttenSysCourseDispatcherTrait,
};
use attendsys::contracts::oracle::PriceFeed;
use attendsys::contracts::oracle::PriceFeed::{
    IPriceFeedExampleABIDispatcher, IPriceFeedExampleABIDispatcherTrait,
};
use pragma_lib::abi::{IPragmaABIDispatcher, IPragmaABIDispatcherTrait};
use pragma_lib::types::{AggregationMode, DataType, PragmaPricesResponse};
// get_caller_address,
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_block_timestamp_global, start_cheat_caller_address, stop_cheat_caller_address,
    test_address,
};
use starknet::{ClassHash, ContractAddress, contract_address_const};
// Pragma Oracle address on Sepolia
const PRAGMA_ORACLE_ADDRESS: felt252 =
    0x36031daa264c24520b11d93af622c848b2499b66b41d611bac95e13cfca131a;
const KEY: felt252 = 6004514686061859652; // STRK/USD 

fn deploy_pricefeed(pragma_contract: ContractAddress) -> ContractAddress {
    let contract = declare("PriceFeedExample").unwrap().contract_class();
    let mut constructor_arg = ArrayTrait::new();

    pragma_contract.serialize(ref constructor_arg);

    let (contract_address, _) = ContractClassTrait::deploy(contract, @constructor_arg).unwrap();
    contract_address
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
#[ignore]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8", block_tag: latest)]
fn test_pricefeed() {
    // Deploy price feed with real Pragma oracle address
    let pricefeed_address = deploy_pricefeed(PRAGMA_ORACLE_ADDRESS.try_into().unwrap());

    let pricefeed = IPriceFeedExampleABIDispatcher { contract_address: pricefeed_address };

    let asset_data_type = DataType::SpotEntry(KEY);
    let price = pricefeed.get_asset_price(asset_data_type);

    // Get price directly from Pragma oracle for comparison
    let oracle = IPragmaABIDispatcher {
        contract_address: PRAGMA_ORACLE_ADDRESS.try_into().unwrap(),
    };
    let oracle_response = oracle.get_data(asset_data_type, AggregationMode::Median(()));

    // Verify the price matches what we get directly from the oracle
    assert(price == oracle_response.price, 'Price should match oracle value');
    println!("Price of STRK/USD: {}", price);
}

#[test]
#[ignore]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8", block_tag: latest)]
fn test_pricefeed_work_with_course_creation() {
    // compare the price of STRK/USD from the course contract with the price from the oracle
    let asset_data_type = DataType::SpotEntry(KEY);
    let oracle = IPragmaABIDispatcher {
        contract_address: PRAGMA_ORACLE_ADDRESS.try_into().unwrap(),
    };
    let oracle_response = oracle.get_data(asset_data_type, AggregationMode::Median(()));
    let price_of_strk_usd = oracle_response.price;
    let (c, hash) = deploy_nft_contract("AttenSysNft");
    let course_contract = deploy_contract("AttenSysCourse", hash);
    let attensys_course_contract = IAttenSysCourseDispatcher { contract_address: course_contract };
    assert(
        attensys_course_contract.get_price_of_strk_usd() == price_of_strk_usd,
        'Price should match oracle',
    );

    let owner: ContractAddress = contract_address_const::<'owner'>();
    let owner_two: ContractAddress = contract_address_const::<'owner_two'>();
    // create a course with price 25 USD
    let base_uri: ByteArray = "https://example.com/";
    let base_uri_2: ByteArray = "https://example.com/";
    let name: ByteArray = "Test Course";
    let symbol: ByteArray = "TC";
    let price: u128 = 25; //25 USD

    start_cheat_caller_address(course_contract, owner);
    attensys_course_contract
        .create_course(
            owner, true, base_uri.clone(), name.clone(), symbol.clone(), base_uri_2.clone(), price,
        );
    stop_cheat_caller_address(course_contract);

    // get_all_courses_info
    let courses = attensys_course_contract.get_all_courses_info();
    assert(courses.len() == 1, 'Course should be created');

    // create a course with price 0 USD
    let price_2: u128 = 0; //0 USD
    start_cheat_caller_address(course_contract, owner_two);
    attensys_course_contract
        .create_course(
            owner_two,
            true,
            base_uri.clone(),
            name.clone(),
            symbol.clone(),
            base_uri_2.clone(),
            price_2,
        );
    stop_cheat_caller_address(course_contract);

    // get_all_courses_info
    let courses = attensys_course_contract.get_all_courses_info();
    assert(courses.len() == 2, 'Course should be created');
}

#[test]
#[ignore]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8", block_tag: latest)]
fn test_update_price() {
    // compare the price of STRK/USD from the course contract with the price from the oracle
    let asset_data_type = DataType::SpotEntry(KEY);
    let oracle = IPragmaABIDispatcher {
        contract_address: PRAGMA_ORACLE_ADDRESS.try_into().unwrap(),
    };
    let oracle_response = oracle.get_data(asset_data_type, AggregationMode::Median(()));
    let price_of_strk_usd = oracle_response.price;
    let (c, hash) = deploy_nft_contract("AttenSysNft");
    let course_contract = deploy_contract("AttenSysCourse", hash);
    let attensys_course_contract = IAttenSysCourseDispatcher { contract_address: course_contract };
    assert(
        attensys_course_contract.get_price_of_strk_usd() == price_of_strk_usd,
        'Price should match oracle value',
    );

    let owner: ContractAddress = contract_address_const::<'owner'>();
    let owner_two: ContractAddress = contract_address_const::<'owner_two'>();
    // create a course with price 25 USD
    let base_uri: ByteArray = "https://example.com/";
    let base_uri_2: ByteArray = "https://example.com/";
    let name: ByteArray = "Test Course";
    let symbol: ByteArray = "TC";
    let price: u128 = 25; //25 USD

    start_cheat_caller_address(course_contract, owner);
    attensys_course_contract
        .create_course(
            owner, true, base_uri.clone(), name.clone(), symbol.clone(), base_uri_2.clone(), price,
        );
    stop_cheat_caller_address(course_contract);

    // update the price to 50 USD
    let price_2: u128 = 50; //50 USD
    start_cheat_caller_address(course_contract, owner);
    attensys_course_contract.update_price(0, price_2);
    stop_cheat_caller_address(course_contract);
}
