use attendsys::components::org::interfaces::IStudentManagement::IStudentManagement;
#[starknet::component]
pub mod StudentManagementComponent {
    use super::AttenSysOrg;
    use attendsys::components::org::types::{
        Bootcamp, Bootcampclass, Class, Instructor, Organization, RegisteredBootcamp, Student,
    };
    use starknet::storage::{
        Map, Mutable, MutableVecTrait, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    pub struct Storage {
        // student_to_classes: Map<ContractAddress, Vec<Class>>,
        // student_info: Map<ContractAddress, Student>,
        // student_attendance_status: Map<(ContractAddress, u64, u64, ContractAddress), bool>,
        // inst_student_status: Map<ContractAddress, Map<ContractAddress, bool>>,
        // certify_student: Map<(ContractAddress, u64, ContractAddress), bool>,
        // certified_students_for_bootcamp: Map<(ContractAddress, u64), Vec<ContractAddress>>,
        // student_address_to_bootcamps: Map<ContractAddress, Vec<RegisteredBootcamp>>,
        // student_address_to_specific_bootcamp: Map<
        //     (ContractAddress, ContractAddress), Vec<RegisteredBootcamp>,
        // >,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(StudentManagementImpl)]
    impl StudentManagementComponentImpl<
        TContractState, +HasComponent<TContractState>,
    > of super::IStudentManagement<ComponentState<TContractState>> {
        fn get_student_classes(
            self: @ComponentState<TContractState>, student: ContractAddress,
        ) -> Array<Class> {
            let mut arr = array![];
            for i in 0..self.student_to_classes.entry(student).len() {
                arr.append(self.student_to_classes.entry(student).at(i).read());
            }
            arr
        }

        fn get_student_info(
            self: @ComponentState<TContractState>, student_: ContractAddress,
        ) -> Student {
            let mut student_info: Student = self.student_info.entry(student_).read();
            student_info
        }

        fn get_registered_bootcamp(
            self: @ComponentState<TContractState>, student: ContractAddress,
        ) -> Array<RegisteredBootcamp> {
            let mut array_of_reg_bootcamp = array![];
            for i in 0..self.student_address_to_bootcamps.entry(student).len() {
                array_of_reg_bootcamp
                    .append(self.student_address_to_bootcamps.entry(student).at(i).read());
            }
            array_of_reg_bootcamp
        }

        fn get_specific_organization_registered_bootcamp(
            self: @ComponentState<TContractState>, org: ContractAddress, student: ContractAddress,
        ) -> Array<RegisteredBootcamp> {
            let mut array_of_specific_org_reg_bootcamp = array![];
            for i in 0..self.student_address_to_specific_bootcamp.entry((org, student)).len() {
                array_of_specific_org_reg_bootcamp
                    .append(
                        self
                            .student_address_to_specific_bootcamp
                            .entry((org, student))
                            .at(i)
                            .read(),
                    );
            }
            array_of_specific_org_reg_bootcamp
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {}
}
