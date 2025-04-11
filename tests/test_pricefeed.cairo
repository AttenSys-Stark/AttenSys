use starknet::{ContractAddress, contract_address_const, ClassHash};
// get_caller_address,
use snforge_std::{
    declare, ContractClassTrait, start_cheat_caller_address, start_cheat_block_timestamp_global,
    spy_events, EventSpyAssertionsTrait, test_address, stop_cheat_caller_address,
};

use attendsys::contracts::oracle::PriceFeed;
use attendsys::contracts::oracle::IPriceFeedExampleDispatcher;
use attendsys::contracts::oracle::IPriceFeedExampleDispatcherTrait;

fn deploy_contract(pragma_contract: ContractAddress) -> ContractAddress {
    let contract = declare(pragma_contract).unwrap();
    let mut constuctor_arg = ArrayTrait::new();

    pragma_contract.serialize(ref constuctor_arg);

    let (contract_address, _) = contract.deploy(@constuctor_arg).unwrap();
    contract_address
}

#[test]
fn test_pricefeed() {
    let pricefeed = PriceFeedExampleDispatcher {
        contract_address: deploy_contract(0x36031daa264c24520b11d93af622c848b2499b66b41d611bac95e13cfca131a),
    };

    let price = pricefeed.get_asset_price(ETH_USD);
    println!("Price: {}", price);
}
