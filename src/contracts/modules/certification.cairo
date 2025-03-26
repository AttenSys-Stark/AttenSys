// Module for certification and NFT minting
pub mod certification_manager {
    use core::starknet::{
        ContractAddress, get_caller_address,
    };
    use super::super::common::{
        BatchCertificationCompleted, EventStruct,
    };

    // Validate certification prerequisites
    pub fn validate_certification(
        event_organizer: ContractAddress,
        caller: ContractAddress,
        is_suspended: bool,
    ) {
        assert(caller == event_organizer, 'not event organizer');
        assert(is_suspended == false, 'event is suspended');
    }

    // Prepare certification data for a batch of attendees
    pub fn prepare_certification_data(
        event_id: u256,
        attendees: Array<ContractAddress>,
    ) -> BatchCertificationCompleted {
        BatchCertificationCompleted {
            event_identifier: event_id,
            attendees: attendees,
        }
    }
} 