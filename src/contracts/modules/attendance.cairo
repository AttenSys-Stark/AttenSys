// Module for attendance tracking and verification
pub mod attendance_manager {
    use core::starknet::{
        ContractAddress, get_caller_address,
    };
    use super::super::common::{
        EventStruct, Time, AttendeeInfo, UserAttendedEventStruct,
    };

    // Validate attendance marking
    pub fn validate_attendance_marking(
        event_details: EventStruct,
        attendee: ContractAddress,
        caller: ContractAddress,
        current_timestamp: u256,
        is_already_marked: bool,
        is_registered: bool,
    ) {
        assert(is_already_marked == false, 'attendance already marked');
        assert(is_registered == true, 'not registered');
        assert(event_details.is_suspended == false, 'event is suspended');
        assert(event_details.active_status == true, 'event not active');
        assert(event_details.canceled == false, 'event cancelled');
        
        // For physical events, only organizer can mark attendance
        if event_details.location == 1 {
            assert(caller == event_details.event_organizer, 'not authorized');
        } else {
            // For online events, attendee can mark their own
            assert(caller == attendee || caller == event_details.event_organizer, 'not authorized');
        }
        
        // Validate time constraints
        let attendance_start_time = event_details.time.start_time;
        let attendance_end_time = event_details.time.end_time;
        assert(current_timestamp >= attendance_start_time, 'event not started');
        assert(current_timestamp <= attendance_end_time, 'event ended');
    }

    // Create attendance data for user
    pub fn create_attendance_data(
        event_details: EventStruct,
    ) -> UserAttendedEventStruct {
        UserAttendedEventStruct {
            event_name: event_details.event_name,
            time: event_details.time,
            event_organizer: event_details.event_organizer,
            event_id: event_details.event_id,
            event_uri: event_details.event_uri,
        }
    }
} 