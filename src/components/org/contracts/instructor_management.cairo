use attendsys::components::org::interfaces::IInstructorManagement::IInstructorManagement;
#[starknet::component]
pub mod InstructorManagementComponent {
    use super::AttenSysOrg;
    use attendsys::components::org::types::Instructor;
    use starknet::storage::{
        Map, Mutable, MutableVecTrait, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    pub struct Storage {
        // instructor_part_of_org: Map<(ContractAddress, ContractAddress), bool>,
        // instructor_key_to_info: Map<ContractAddress, Vec<Instructor>>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(InstructorManagementImpl)]
    impl InstructorManagementComponentImpl<
        TContractState, +HasComponent<TContractState>,
    > of super::IInstructorManagement<ComponentState<TContractState>> {
        fn get_instructor_part_of_org(
            self: @ComponentState<TContractState>, instructor: ContractAddress,
        ) -> bool {
            let creator = get_caller_address();
            let isTrue = self.instructor_part_of_org.entry((creator, instructor)).read();
            return isTrue;
        }

        fn get_instructor_info(
            self: @ComponentState<TContractState>, instructor: ContractAddress,
        ) -> Array<Instructor> {
            let mut arr = array![];
            for i in 0..self.instructor_key_to_info.entry(instructor).len() {
                arr.append(self.instructor_key_to_info.entry(instructor).at(i).read());
            }
            arr
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {}
}
