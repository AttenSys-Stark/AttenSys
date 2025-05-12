use attendsys::contracts::registry::data::{
    AttensysUserData, IAttensysUserDataDispatcher, IAttensysUserDataDispatcherTrait,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::{ContractAddress, contract_address_const};

fn deploy_contract() -> ContractAddress {
    let contract = declare("AttensysUserData").unwrap().contract_class();
    let (contract_address, _) = ContractClassTrait::deploy(contract, @array![]).unwrap();

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

    let user = dispatcher.get_specific_user(caller);
    assert!(user.name == 'firstname', "Not stored user name");
}

#[test]
#[should_panic(expected: 'Invalid name or uri')]
fn test_create_name_should_panic() {
    let contract_address = deploy_contract();
    let dispatcher = IAttensysUserDataDispatcher { contract_address };
    let caller = contract_address_const::<'caller'>();

    start_cheat_caller_address(contract_address, caller);
    dispatcher.create_name('', 'Qed85tyuu45ggtCfG6hy');
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: 'name already taken')]
fn test_create_name_should_panic_name_already_taken() {
    let contract_address = deploy_contract();
    let dispatcher = IAttensysUserDataDispatcher { contract_address };
    let caller = contract_address_const::<'caller'>();
    let caller2 = contract_address_const::<'caller2'>();

    start_cheat_caller_address(contract_address, caller);
    dispatcher.create_name('firstname', 'Qed85tyuu45ggtCfG6hy');
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, caller2);
    dispatcher.create_name('firstname', 'Qed85tyuu45ggtCfG6hy');
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_get_all_users() {
    let contract_address = deploy_contract();
    let dispatcher = IAttensysUserDataDispatcher { contract_address };
    let caller = contract_address_const::<'caller'>();
    let caller2 = contract_address_const::<'caller2'>();
    let caller3 = contract_address_const::<'caller3'>();
    let caller4 = contract_address_const::<'caller4'>();

    start_cheat_caller_address(contract_address, caller);
    dispatcher.create_name('first_user', 'Qed85tyuu45ggtCfG6hy');
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, caller2);
    dispatcher.create_name('second_user', 'Qed85tyuu45ggtCfG6hy');
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, caller3);
    dispatcher.create_name('third_user', 'Qed85tyuu45ggtCfG6hy');
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, caller4);
    dispatcher.create_name('fourth_user', 'Qed85tyuu45ggtCfG6hy');
    stop_cheat_caller_address(contract_address);

    let all_users = dispatcher.get_all_users();
    assert(all_users.len() == 4, 'Inaccurate no of users');
}
