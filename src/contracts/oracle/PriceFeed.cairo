use pragma_lib::types::{AggregationMode, DataType, PragmaPricesResponse};

#[starknet::interface]
pub trait IPriceFeedExampleABI<TContractState> {
    fn get_asset_price(self: @TContractState, asset_type: DataType) -> u128;
}

#[starknet::contract]
mod PriceFeedExample {
    use pragma_lib::abi::{IPragmaABIDispatcher, IPragmaABIDispatcherTrait};
    use pragma_lib::types::{AggregationMode, DataType, PragmaPricesResponse};
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    struct Storage {
        pragma_contract: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, pragma_address: ContractAddress) {
        self.pragma_contract.write(pragma_address);
    }

    #[external(v0)]
    impl PriceFeedExampleABIImpl of super::IPriceFeedExampleABI<ContractState> {
        fn get_asset_price(self: @ContractState, asset_type: DataType) -> u128 {
            // Retrieve the oracle dispatcher
            let oracle_dispatcher = IPragmaABIDispatcher {
                contract_address: self.pragma_contract.read(),
            };

            // Get price data from oracle
            let price_response: PragmaPricesResponse = oracle_dispatcher
                .get_data(asset_type, AggregationMode::Median(()));

            // Verify we got a valid price
            assert(price_response.price > 0, 'Invalid price from oracle');
            assert(price_response.num_sources_aggregated > 0, 'No price sources available');

            price_response.price
        }
    }
}
