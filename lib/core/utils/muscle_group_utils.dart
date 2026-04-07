/// Comparação de nomes de grupo muscular (evita duplicatas como "Peitoral" / "peitoral ").
String normalizeMuscleGroupName(String raw) => raw.trim().toLowerCase();
