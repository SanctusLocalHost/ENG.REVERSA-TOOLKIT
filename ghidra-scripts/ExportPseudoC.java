// ============================================================================
//  ExportPseudoC.java — Script Ghidra headless do ENG. REVERSA
// ----------------------------------------------------------------------------
//  Exporta TODAS as funções do binário como pseudocódigo C + um índice TSV.
//
//  Uso (via eng ghidra, ou direto):
//    analyzeHeadless <proj> <nome> -import <bin> \
//      -scriptPath "<ENG. REVERSA>/ghidra-scripts" \
//      -postScript ExportPseudoC.java <dir-saida>
//
//  Saída:
//    <dir-saida>/index-funcoes.tsv   (# endereço, nome, tamanho, assinatura)
//    <dir-saida>/<endereço>_<nome>.c (pseudocódigo de cada função)
// ============================================================================
import java.io.File;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.List;

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileOptions;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionManager;

public class ExportPseudoC extends GhidraScript {

    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 1) {
            printerr("Uso: ExportPseudoC.java <dir-saida>");
            return;
        }
        File outDir = new File(args[0]);
        if (!outDir.exists() && !outDir.mkdirs()) {
            printerr("Não foi possível criar o diretório: " + outDir.getAbsolutePath());
            return;
        }

        DecompInterface ifc = new DecompInterface();
        ifc.setOptions(new DecompileOptions());
        if (!ifc.openProgram(currentProgram)) {
            printerr("Falha ao abrir o programa no decompilador: " + ifc.getLastMessage());
            return;
        }

        FunctionManager fm = currentProgram.getFunctionManager();
        int total = 0, exportadas = 0;
        List<String> indice = new ArrayList<>();
        indice.add("# endereco\tnome\ttamanho_bytes\tassinatura");

        for (Function f : fm.getFunctions(true)) {
            if (monitor.isCancelled()) break;
            total++;

            String nome = f.getName();
            long endereco = f.getEntryPoint().getOffset();
            long tamanho = f.getBody() != null ? f.getBody().getNumAddresses() : 0;

            String assinatura = nome;
            try {
                assinatura = f.getSignature().getPrototypeString();
            } catch (Throwable t) {
                // mantém o nome simples se a API variar entre versões do Ghidra
            }

            indice.add(String.format("%08x\t%s\t%d\t%s",
                    endereco, nome, tamanho, assinatura));

            try {
                DecompileResults res = ifc.decompileFunction(f, 60, monitor);
                if (res != null && res.decompileCompleted() && res.getDecompiledFunction() != null) {
                    String c = res.getDecompiledFunction().getC();
                    String arquivo = String.format("%08x_%s.c", endereco, sanitizar(nome));
                    try (PrintWriter pw = new PrintWriter(new File(outDir, arquivo), "UTF-8")) {
                        pw.print(c);
                    }
                    exportadas++;
                }
            } catch (Throwable t) {
                println("AVISO: falha ao descompilar " + nome + " @ " + Long.toHexString(endereco) + ": " + t.getMessage());
            }
        }

        try (PrintWriter pw = new PrintWriter(new File(outDir, "index-funcoes.tsv"), "UTF-8")) {
            for (String linha : indice) pw.println(linha);
        }

        println("ExportPseudoC: " + exportadas + "/" + total + " funções exportadas para " + outDir.getAbsolutePath());
        ifc.dispose();
    }

    private String sanitizar(String s) {
        StringBuilder sb = new StringBuilder();
        for (char ch : s.toCharArray()) {
            sb.append((Character.isLetterOrDigit(ch) || ch == '_' || ch == '.') ? ch : '_');
        }
        String out = sb.toString();
        return out.length() > 80 ? out.substring(0, 80) : out;
    }
}
