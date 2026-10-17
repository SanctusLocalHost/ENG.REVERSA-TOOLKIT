// ============================================================================
//  ExportStrings.java — Script Ghidra headless do ENG. REVERSA
// ----------------------------------------------------------------------------
//  Exporta todas as strings definidas (com endereço) para um TSV.
//  Útil para achar mensagens, URLs, chaves, nomes de assets etc.
//
//  Uso (via eng ghidra, ou direto):
//    analyzeHeadless <proj> <nome> -import <bin> \
//      -scriptPath "<ENG. REVERSA>/ghidra-scripts" \
//      -postScript ExportStrings.java <dir-saida>
// ============================================================================
import java.io.File;
import java.io.PrintWriter;

import ghidra.app.script.GhidraScript;
import ghidra.program.model.data.AbstractStringDataType;
import ghidra.program.model.listing.Data;
import ghidra.program.model.listing.DataIterator;
import ghidra.program.util.DefinedDataIterator;

public class ExportStrings extends GhidraScript {

    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 1) {
            printerr("Uso: ExportStrings.java <dir-saida>");
            return;
        }
        File outDir = new File(args[0]);
        if (!outDir.exists() && !outDir.mkdirs()) {
            printerr("Não foi possível criar o diretório: " + outDir.getAbsolutePath());
            return;
        }

        File destino = new File(outDir, "strings.tsv");
        int n = 0;
        try (PrintWriter pw = new PrintWriter(destino, "UTF-8")) {
            pw.println("# endereco\tstring");
            DataIterator it = DefinedDataIterator.byDataType(
                    currentProgram,
                    dt -> dt instanceof AbstractStringDataType);
            while (it.hasNext() && !monitor.isCancelled()) {
                Data d = it.next();
                pw.println(d.getAddress() + "\t" + d.getDefaultValueRepresentation());
                n++;
            }
        }
        println("ExportStrings: " + n + " strings exportadas para " + destino.getAbsolutePath());
    }
}
