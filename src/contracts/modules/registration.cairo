// Module for registration management
pub mod registration_manager {
    use core::starknet::{
        ContractAddress, get_caller_address,
    };
    use super::super::common::{
        EventStruct, Time, AttendeeInfo, UserAttendedEventStruct,
    };

    // Validate registration status
    pub fn validate_reg_status(reg_stat: u8) {
        assert(reg_stat == 0 || reg_stat == 1, 'invalid reg status');
    }

    // Register for event validation
    pub fn validate_registration(
        event_details: EventStruct,
        caller: ContractAddress,
        is_already_registered: bool,
        current_timestamp: u256,
    ) {
        assert(event_details.is_suspended == false, 'event is suspended');
        assert(event_details.time.registration_open == 1, 'registration closed');
        assert(is_already_registered == false, 'already registered');
        assert(event_details.active_status == true, 'event not active');
        assert(event_details.canceled == false, 'event cancelled');
        
        // Validate time constraints
        let start_time = event_details.time.start_time;
        assert(current_timestamp <= start_time, 'event already started');
    }

    // Get registration status
    pub fn get_registration_status(
        event_details: EventStruct,
        current_timestamp: u256,
    ) -> u8 {
        if event_details.time.registration_open == 1 && 
           current_timestamp <= event_details.time.start_time && 
           event_details.active_status == true && 
           event_details.canceled == false && 
           event_details.is_suspended == false {
            return 1;
        } else {
            return 0;
        }
    }

    // Create registration data
    pub fn create_registration_data(
        event_details: EventStruct,
        attendee: ContractAddress,
        user_uri: ByteArray,
    ) -> (AttendeeInfo, UserAttendedEventStruct) {
        let attendee_info = AttendeeInfo {
            attendee_address: attendee,
            attendee_uri: user_uri,
        };
        
        let user_event_struct = UserAttendedEventStruct {
            event_name: event_details.event_name,
            time: event_details.time,
            event_organizer: event_details.event_organizer,
            event_id: event_details.event_id,
            event_uri: event_details.event_uri,
        };
        
        (attendee_info, user_event_struct)
    }
} 