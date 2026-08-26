# diagnose-plugin-build.sh - READ ONLY apart from a throwaway compile.
#
# The build failed with "cannot find symbol" for basic API members - getServer(),
# reloadConfig(), even class Player. Those are cascades; the FIRST error is what
# matters, and the build script only tails the last 30 lines.
#
# Leading hypothesis: Minecraft 26.x requires Java 25, so paper-api 26.2 is compiled
# to a class file version that a `--release 21` compile cannot read - which javac
# reports as every symbol being missing rather than as a version problem.

SRC=/home/ubuntu/laughtail-plugin
M2=/home/ubuntu/.m2
IMAGE=maven:3.9.9-eclipse-temurin-21

echo "=== what class file version is paper-api compiled to? ==="
JAR=$(find "$M2" -name 'paper-api-26.2.build.119-stable.jar' 2>/dev/null | head -1)
echo "jar: ${JAR:-not found in the local repository}"
if [ -n "$JAR" ]; then
  sudo -n docker run --rm -v "$M2":/m2 "$IMAGE" sh -c "
    cd /tmp && unzip -o -q '${JAR#$M2}' 'org/bukkit/Bukkit.class' -d /tmp/x 2>/dev/null || true
  " 2>/dev/null || true
  # Simpler and reliable: ask javap through the same image, using the jar on the classpath.
  sudo -n docker run --rm -v "$M2":/root/.m2 "$IMAGE" \
    sh -c "javap -verbose -cp '/root/.m2/${JAR#$M2/}' org.bukkit.Bukkit 2>/dev/null | grep -m2 -E 'major|minor'" \
    || echo "  (javap could not read it)"
fi

echo ""
echo "=== first 40 lines of the actual failure ==="
sudo -n docker run --rm \
  --memory 640m --memory-swap 640m --cpus 1.5 \
  -u "$(id -u ubuntu):$(id -g ubuntu)" \
  -e HOME=/var/maven -e MAVEN_CONFIG=/var/maven/.m2 \
  -v "$SRC":/src -v "$M2":/var/maven/.m2 -w /src \
  "$IMAGE" mvn -B -DskipTests -Dmaven.repo.local=/var/maven/.m2/repository compile 2>&1 \
  | grep -E 'ERROR|BUILD|release|version|source|target' | head -40

echo ""
echo "=== is there a maven image with JDK 25? ==="
for img in maven:3.9-eclipse-temurin-25 maven:3.9.9-eclipse-temurin-25 maven:eclipse-temurin-25; do
  if sudo -n docker manifest inspect "$img" >/dev/null 2>&1; then
    echo "  AVAILABLE: $img"
  else
    echo "  not available: $img"
  fi
done
echo "=== END ==="
