import { promises as fs } from "fs";
import path from "path";

export async function getCompiledCode(filenameA: string, filenameB: string, filenameC: string) {
    const AsierraFilePath = path.join(
    __dirname,
    `../target/dev/${filenameA}.contract_class.json`
    );
    const AcasmFilePath = path.join(
    __dirname,
    `../target/dev/${filenameA}.compiled_contract_class.json`
    );

    const BsierraFilePath = path.join(
        __dirname,
        `../target/dev/${filenameB}.contract_class.json`
        );
    const BcasmFilePath = path.join(
        __dirname,
        `../target/dev/${filenameB}.compiled_contract_class.json`
    );
    
    const CsierraFilePath = path.join(
        __dirname,
        `../target/dev/${filenameC}.contract_class.json`
        );
    const CcasmFilePath = path.join(
        __dirname,
        `../target/dev/${filenameC}.compiled_contract_class.json`
        );
    
    
    
    
    const codeA = [AsierraFilePath, AcasmFilePath].map(async (filePath) => {
        const file = await fs.readFile(filePath);
        return JSON.parse(file.toString("ascii"));
    });
    const [AsierraCode, AcasmCode] = await Promise.all(codeA);



    const codeB = [BsierraFilePath, BcasmFilePath].map(async (filePath) => {
        const file = await fs.readFile(filePath);
        return JSON.parse(file.toString("ascii"));
    });
    const [BsierraCode, BcasmCode] = await Promise.all(codeB);



    const codeC = [CsierraFilePath, CcasmFilePath].map(async (filePath) => {
        const file = await fs.readFile(filePath);
        return JSON.parse(file.toString("ascii"));
    });
    const [CsierraCode, CcasmCode] = await Promise.all(codeC);

    return {
        AsierraCode, AcasmCode, BsierraCode, BcasmCode, CsierraCode, CcasmCode
    };
}