A planner is a module that converts SkullQL AST into real queries to execute in the database.
We have basically these builtin plans:

1. **Node Scan**: It describes a complete scan in a node.
2. **Index Scan**: This plan is used to scan node indices by label.
3. **Expand**: Used to unwrap relationships between nodes or more complex expressions, casting it into a more explicit structure.
4. **Filter**: Used to filter nodes based on a logical requirement.
5. **Project**: It simply returns data.
6. **Pipe**: Used to chain multiple patterns.