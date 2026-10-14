"""Compare folding with Python integers for every pair of i4 bit patterns."""

import pathlib
import re
import subprocess
import sys


def main():
    opt, plugin, prefix = sys.argv[1:]
    source = pathlib.Path(prefix + ".ll")
    transformed = pathlib.Path(prefix + ".out.ll")
    mask = 15
    cases = []
    definitions = []
    operations = {
        "add": lambda a, b: a + b,
        "sub": lambda a, b: a - b,
        "mul": lambda a, b: a * b,
        "and": lambda a, b: a & b,
        "or": lambda a, b: a | b,
        "xor": lambda a, b: a ^ b,
    }
    for opcode, operation in operations.items():
        flags = ("", "nsw", "nuw", "nsw nuw") if opcode in ("add", "sub", "mul") else ("",)
        for flag in flags:
            for a in range(16):
                for b in range(16):
                    name = f"case_{len(cases)}"
                    instruction = f"{opcode} {flag} i4 {a}, {b}"
                    definitions.append(
                        f"define i4 @{name}() {{\n  %v = {instruction}\n  ret i4 %v\n}}\n"
                    )
                    signed_a = a if a < 8 else a - 16
                    signed_b = b if b < 8 else b - 16
                    signed_result = operation(signed_a, signed_b)
                    unsigned_result = operation(a, b)
                    poison = ("nsw" in flag and not -8 <= signed_result <= 7) or (
                        "nuw" in flag and not 0 <= unsigned_result <= mask
                    )
                    cases.append((name, opcode, poison, unsigned_result & mask))
    source.write_text("\n".join(definitions), encoding="utf-8")
    subprocess.run([
        opt, f"-load-pass-plugin={plugin}", "-passes=optiforge-constant-folding",
        "-verify-each", "-S", str(source), "-o", str(transformed),
    ], check=True)
    bodies = dict(re.findall(r"define i4 @(case_\d+)\(\) \{(.*?)\n\}", transformed.read_text(), re.S))
    for name, opcode, poison, expected in cases:
        body = bodies[name]
        if poison:
            if f"= {opcode} " not in body or "ret i4 %v" not in body:
                raise AssertionError(f"{name}: poison-producing operation was changed: {body}")
        else:
            match = re.search(r"ret i4 (-?\d+)", body)
            if not match or int(match.group(1)) & mask != expected or " = " in body:
                raise AssertionError(f"{name}: expected constant {expected}: {body}")
    print(f"Verified {len(cases)} exhaustive i4 cases against Python integer semantics")


if __name__ == "__main__":
    main()
