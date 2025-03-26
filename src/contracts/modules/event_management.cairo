// Module for event management functions
pub mod event_manager {
    use core::starknet::{
        ContractAddress, get_caller_address, get_block_timestamp, ClassHash,
        syscalls::deploy_syscall, contract_address_const,
    };
    use super::super::common::{EventStruct, Time, EventCreated, EventEnded, RegistrationStatusChanged};

    // Create an event
    pub fn create_event(
        owner_: ContractAddress,
        event_name: ByteArray,
        base_uri: ByteArray,
        name_: ByteArray,
        symbol: ByteArray,
        start_time_: u256,
        end_time_: u256,
        reg_status: u8,
        event_uri: ByteArray,
        event_location: u8,
        hash: ClassHash,
        event_id: u256,
    ) -> (ContractAddress, EventStruct) {
        assert(event_location < 2 && event_location >= 0, 'invalid input');
        assert(reg_status < 2 && reg_status >= 0, 'invalid input');
        
        let time_data: Time = Time {
            registration_open: reg_status, start_time: start_time_, end_time: end_time_,
        };
        
        let mut constructor_args = array![];
        base_uri.serialize(ref constructor_args);
        name_.serialize(ref constructor_args);
        symbol.serialize(ref constructor_args);
        
        let contract_address_salt: felt252 = event_id.try_into().unwrap();
        
        let (deployed_contract_address, _) = deploy_syscall(
            hash, contract_address_salt, constructor_args.span(), false,
        ).expect('failed to deploy_syscall');
        
        let event_struct = EventStruct {
            event_name: event_name,
            time: time_data,
            active_status: true,
            signature_count: 0,
            event_organizer: owner_,
            registered_attendants: 0,
            event_uri: event_uri,
            is_suspended: false,
            event_id: event_id,
            location: event_location,
            canceled: false,
        };
        
        (deployed_contract_address, event_struct)
    }
    
    // End an event
    pub fn end_event(event_details: EventStruct) -> Time {
        let time_data: Time = Time {
            registration_open: 0, 
            start_time: event_details.time.start_time, 
            end_time: 0,
        };
        
        time_data
    }
    
    // Validate registration status
    pub fn validate_reg_status(reg_stat: u8) {
        assert(reg_stat < 2 && reg_stat >= 0, 'invalid input');
    }
} 