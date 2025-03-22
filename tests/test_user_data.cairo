use snforge_std::{ declare, ContractClassTrait, start_cheat_caller_address, stop_cheat_caller_address };
use starknet::{ ContractAddress, contract_address_const };
use attendsys::contracts::data::{ AttensysUserData, IAttensysUserDataDispatcher, IAttensysUserDataDispatcherTrait };

fn deploy_contract() -> ContractAddress {

    let contract = declare("AttensysUserData").unwrap();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    contract_address
}

#[test]
fn test_create_name() {
    let contract_address = deploy_contract();
    let dispatcher = IAttensysUserDataDispatcher { contract_address };
    let caller = contract_address_const::<'caller'>();

    start_cheat_caller_address(contract_address, caller);
    dispatcher.create_name('firstname', 'Qed85tyuu45ggtCfG6hy');
    stop_cheat_caller_address(contract_address);

    
}
