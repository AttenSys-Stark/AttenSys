import { Account, CallData, Contract, RpcProvider, stark } from "starknet";
import * as dotenv from "dotenv";
import { getCompiledCode } from "./utils";
import fs from 'fs';
import path from 'path';
import prettier from "prettier";
dotenv.config();

 async function main() {
    const provider = new RpcProvider({
        nodeUrl: process.env.RPC_ENDPOINT,
    });

    console.log("ACCOUNT_ADDRESS=", process.env.DEPLOYER_ADDRESS);
    const privateKey0 = process.env.DEPLOYER_PRIVATE_KEY ?? "";
    const accountAddress0: string = process.env.DEPLOYER_ADDRESS ?? "";
    const account0 = new Account(provider, accountAddress0, privateKey0);
    console.log("Account connected.\n");

    let AsierraCode, AcasmCode, BsierraCode, BcasmCode, CsierraCode, CcasmCode, DsierraCode: any, DcasmCode: any, KsierraCode, KcasmCode;

    try {
        ({ AsierraCode, AcasmCode, BsierraCode, BcasmCode, CsierraCode, CcasmCode, DsierraCode, DcasmCode, KsierraCode, KcasmCode } = await getCompiledCode(
            "attendsys_AttenSysCourse", "attendsys_AttenSysEvent", "attendsys_AttenSysOrg", "attendsys_AttenSysNft", "attendsys_AttenSysSponsor"
        ));
    } catch (error: any) {
        console.log("Failed to read contract files");
        console.log(error);
        process.exit(1);
    }
    console.log("declaring contracts...\n") 
    const coursedeclareResponse = await account0.declare({
        contract: AsierraCode,
        casm: AcasmCode,
      });
      console.log('Attensys Course Contract declared with classHash =', coursedeclareResponse.class_hash);

    //   const EventdeclareResponse = await account0.declare({
    //     contract: BsierraCode,
    //     casm: BcasmCode,
    //   });
    //   console.log('Attensys Event Contract declared with classHash =', EventdeclareResponse.class_hash);

    //   const OrgdeclareResponse = await account0.declare({
    //     contract: CsierraCode,
    //     casm: CcasmCode,
    //   });
    //   console.log('Attensys Org Contract declared with classHash =', OrgdeclareResponse.class_hash);
    
 }

 main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });