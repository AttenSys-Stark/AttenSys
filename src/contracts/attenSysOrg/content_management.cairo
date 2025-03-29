use core::starknet::{ContractAddress, get_caller_address};
use crate::base::types::{Bootcamp};
use crate::events::{ActiveMeetLinkAdded, VideoLinkUploaded};
use crate::storage_groups::{MediaStorage, BootcampStorage};

#[starknet::interface]
pub trait IContentManagement<TContractState> {
    fn add_active_meet_link(
        ref self: TContractState,
        meet_link: ByteArray,
        bootcamp_id: u64,
        is_instructor: bool,
        org_address: ContractAddress,
    );
    fn add_uploaded_video_link(
        ref self: TContractState,
        video_link: ByteArray,
        is_instructor: bool,
        org_address: ContractAddress,
        bootcamp_id: u64,
    );
    fn get_bootcamp_active_meet_link(
        self: @TContractState, org_: ContractAddress, bootcamp_id: u64,
    ) -> ByteArray;
    fn get_bootcamp_uploaded_video_link(
        self: @TContractState, org_: ContractAddress, bootcamp_id: u64,
    ) -> Array<ByteArray>;
}

#[generate_trait]
pub impl ContentManagement of IContentManagement<ContractState> {
    fn add_active_meet_link(
        ref self: ContractState,
        meet_link: ByteArray,
        bootcamp_id: u64,
        is_instructor: bool,
        org_address: ContractAddress,
    ) {
        let mut status: bool = false;
        let caller = get_caller_address();
        let active_link = meet_link.clone();
        let is_instructor_cp = is_instructor.clone();
        if is_instructor {
            status = self.instructor_part_of_org.entry((org_address, caller)).read();
        } else {
            assert(org_address == caller, 'caller not org address');
            status = self.created_status.entry(caller).read();
        }

        // confirm that the caller is associated an organization
        if (status) {
            assert(
                !self.bootcamp_suspended.entry(org_address).entry(bootcamp_id).read(),
                'Bootcamp suspended',
            );
            if is_instructor {
                let mut bootcamp: Bootcamp = self
                    .org_to_bootcamps
                    .entry(org_address)
                    .at(bootcamp_id)
                    .read();
                bootcamp.active_meet_link = meet_link;
                self.org_to_bootcamps.entry(org_address).at(bootcamp_id).write(bootcamp);
            } else {
                let mut bootcamp: Bootcamp = self
                    .org_to_bootcamps
                    .entry(caller)
                    .at(bootcamp_id)
                    .read();

                bootcamp.active_meet_link = meet_link;
                self.org_to_bootcamps.entry(caller).at(bootcamp_id).write(bootcamp);
            }
            // pub meet_link: ByteArray,
            // pub bootcamp_id: u64,
            // pub is_instructor: bool,
            // pub org_address: ContractAddress,

            // Emitting events when a active link is added

            self
                .emit(
                    ActiveMeetLinkAdded {
                        meet_link: active_link,
                        bootcamp_id: bootcamp_id.clone(),
                        is_instructor: is_instructor_cp,
                        org_address: org_address,
                    },
                );
        } else {
            panic!("not part of organization.");
        };
    }
    
    
    //Add function to allow saving URI's from recorded video #33
        // Add function to allow organization to save the uri obtained from uploading recorded video
        // to ipfs in contract
    fn add_uploaded_video_link(
            ref self: ContractState,
            video_link: ByteArray,
            is_instructor: bool,
            org_address: ContractAddress,
            bootcamp_id: u64,
        ) {
            assert(video_link != "", 'empty link');
            let video_link_cp = video_link.clone();
            let mut status: bool = false;
            let caller = get_caller_address();
            let is_instructor_cp = is_instructor.clone();
            if is_instructor {
                status = self.instructor_part_of_org.entry((org_address, caller)).read();
            } else {
                assert(org_address == caller, 'caller not org address');
                status = self.created_status.entry(caller).read();
            }

            // confirm that the caller is associated an organization
            if (status) {
                assert(
                    !self.bootcamp_suspended.entry(org_address).entry(bootcamp_id).read(),
                    'Bootcamp suspended',
                );
                if is_instructor {
                    self
                        .org_to_uploaded_videos_link
                        .entry((org_address, bootcamp_id))
                        .append()
                        .write(video_link);
                } else {
                    self
                        .org_to_uploaded_videos_link
                        .entry((caller, bootcamp_id))
                        .append()
                        .write(video_link);
                }

                self
                    .emit(
                        VideoLinkUploaded {
                            video_link: video_link_cp,
                            is_instructor: is_instructor_cp,
                            org_address: org_address,
                            bootcamp_id: bootcamp_id,
                        },
                    );
            } else {
                panic!("not part of organization.");
            };
        }
    
    // Implement other functions from the interface...
}