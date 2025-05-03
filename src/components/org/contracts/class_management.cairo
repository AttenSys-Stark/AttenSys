use attendsys::components::org::interfaces::IClassManagement::IClassManagement;
#[starknet::component]
pub mod ClassManagementComponent {
    use super::AttenSysOrg;
    use attendsys::components::org::types::Class;
    use starknet::storage::{
        Map, Mutable, MutableVecTrait, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AttendanceMarked: AttendanceMarked,
    }
    #[derive(Drop, starknet::Event)]
    pub struct AttendanceMarked {
        pub org_address: ContractAddress,
        pub instructor_address: ContractAddress,
        pub class_id: u64,
    }

    #[embeddable_as(ClassManagementImpl)]
    impl ClassManagementComponentImpl<
        TContractState, +HasComponent<TContractState>,
    > of super::IClassManagement<ComponentState<TContractState>> {
        fn mark_attendance_for_a_class(
            ref self: ComponentState<TContractState>,
            org_: ContractAddress,
            instructor_: ContractAddress,
            class_id: u64,
            bootcamp_id: u64,
        ) {
            let caller = get_caller_address();
            let class_id_len = self.bootcamp_class_data_id.entry((org_, bootcamp_id)).len();
            assert(class_id < class_id_len && class_id >= 0, 'invalid class id');
            let mut instructor_class = self
                .org_instructor_classes
                .entry((org_, instructor_))
                .at(class_id)
                .read();
            let reg_status = self
                .student_attendance_status
                .entry((caller, bootcamp_id, class_id, caller))
                .read();
            assert(instructor_class.active_status, 'not a class');
            assert(!reg_status, 'attendance marked');
            self.student_attendance_status.entry((org_, bootcamp_id, class_id, caller)).write(true);
            self
                .emit(
                    AttendanceMarked {
                        org_address: org_, instructor_address: instructor_, class_id: class_id,
                    },
                );
        }

        fn get_class_attendance_status(
            self: @ComponentState<TContractState>,
            org: ContractAddress,
            bootcamp_id: u64,
            class_id: u64,
            student: ContractAddress,
        ) -> bool {
            let mut instructor_class = self
                .org_instructor_classes
                .entry((org, org))
                .at(class_id)
                .read();
            assert(instructor_class.active_status, 'not a class');
            let class_id_len = self.bootcamp_class_data_id.entry((org, bootcamp_id)).len();
            assert(class_id < class_id_len && class_id >= 0, 'invalid class id');

            let reg_status = self
                .student_attendance_status
                .entry((org, bootcamp_id, class_id, student))
                .read();
            reg_status
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {}
}
