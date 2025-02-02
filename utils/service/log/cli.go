package log

import (
	"fmt"
	"os"
	"strings"

	"github.com/ethereum/go-ethereum/log"
	"github.com/urfave/cli"
	cliV2 "github.com/urfave/cli/v2"
	"golang.org/x/term"

	kservice "github.com/kroma-network/kroma/utils/service"
)

const (
	LevelFlagName  = "log.level"
	FormatFlagName = "log.format"
	ColorFlagName  = "log.color"
)

func CLIFlags(envPrefix string) []cli.Flag {
	return []cli.Flag{
		cli.StringFlag{
			Name:   LevelFlagName,
			Usage:  "The lowest log level that will be output",
			Value:  "info",
			EnvVar: kservice.PrefixEnvVar(envPrefix, "LOG_LEVEL"),
		},
		cli.StringFlag{
			Name:   FormatFlagName,
			Usage:  "Format the log output. Supported formats: 'text', 'terminal', 'logfmt', 'json', 'json-pretty',",
			Value:  "text",
			EnvVar: kservice.PrefixEnvVar(envPrefix, "LOG_FORMAT"),
		},
		cli.BoolFlag{
			Name:   ColorFlagName,
			Usage:  "Color the log output if in terminal mode",
			EnvVar: kservice.PrefixEnvVar(envPrefix, "LOG_COLOR"),
		},
	}
}

func CLIFlagsV2(envPrefix string) []cliV2.Flag {
	return []cliV2.Flag{
		&cliV2.StringFlag{
			Name:    LevelFlagName,
			Usage:   "The lowest log level that will be output",
			Value:   "info",
			EnvVars: kservice.PrefixEnvVarV2(envPrefix, "LOG_LEVEL"),
		},
		&cliV2.StringFlag{
			Name:    FormatFlagName,
			Usage:   "Format the log output. Supported formats: 'text', 'terminal', 'logfmt', 'json', 'json-pretty',",
			Value:   "text",
			EnvVars: kservice.PrefixEnvVarV2(envPrefix, "LOG_FORMAT"),
		},
		&cliV2.BoolFlag{
			Name:    ColorFlagName,
			Usage:   "Color the log output if in terminal mode",
			EnvVars: kservice.PrefixEnvVarV2(envPrefix, "LOG_COLOR"),
		},
	}
}

type CLIConfig struct {
	Level  string // Log level: trace, debug, info, warn, error, crit. Capitals are accepted too.
	Color  bool   // Color the log output. Defaults to true if terminal is detected.
	Format string // Format the log output. Supported formats: 'text', 'terminal', 'logfmt', 'json', 'json-pretty'
}

func (cfg CLIConfig) Check() error {
	switch cfg.Format {
	case "json", "json-pretty", "terminal", "text", "logfmt":
	default:
		return fmt.Errorf("unrecognized log format: %s", cfg.Format)
	}

	level := strings.ToLower(cfg.Level)
	_, err := log.LvlFromString(level)
	if err != nil {
		return fmt.Errorf("unrecognized log level: %w", err)
	}
	return nil
}

func NewLogger(cfg CLIConfig) log.Logger {
	handler := log.StreamHandler(os.Stdout, Format(cfg.Format, cfg.Color))
	handler = log.SyncHandler(handler)
	handler = log.LvlFilterHandler(Level(cfg.Level), handler)
	// Set the root handle to what we have configured. Some components like go-ethereum's RPC
	// server use log.Root() instead of being able to pass in a log.
	log.Root().SetHandler(handler)
	logger := log.New()
	logger.SetHandler(handler)
	return logger
}

func DefaultCLIConfig() CLIConfig {
	return CLIConfig{
		Level:  "info",
		Format: "text",
		Color:  term.IsTerminal(int(os.Stdout.Fd())),
	}
}

func ReadLocalCLIConfig(ctx *cli.Context) CLIConfig {
	cfg := DefaultCLIConfig()
	cfg.Level = ctx.String(LevelFlagName)
	cfg.Format = ctx.String(FormatFlagName)
	if ctx.IsSet(ColorFlagName) {
		cfg.Color = ctx.Bool(ColorFlagName)
	}
	return cfg
}

func ReadCLIConfig(ctx *cli.Context) CLIConfig {
	cfg := DefaultCLIConfig()
	cfg.Level = ctx.GlobalString(LevelFlagName)
	cfg.Format = ctx.GlobalString(FormatFlagName)
	if ctx.IsSet(ColorFlagName) {
		cfg.Color = ctx.GlobalBool(ColorFlagName)
	}
	return cfg
}

func ReadCLIConfigV2(ctx *cliV2.Context) CLIConfig {
	cfg := DefaultCLIConfig()
	cfg.Level = ctx.String(LevelFlagName)
	cfg.Format = ctx.String(FormatFlagName)
	if ctx.IsSet(ColorFlagName) {
		cfg.Color = ctx.Bool(ColorFlagName)
	}
	return cfg
}

// Format turns a string and color into a structured Format object
func Format(lf string, color bool) log.Format {
	switch lf {
	case "json":
		return log.JSONFormat()
	case "json-pretty":
		return log.JSONFormatEx(true, true)
	case "text":
		if term.IsTerminal(int(os.Stdout.Fd())) {
			return log.TerminalFormat(color)
		} else {
			return log.LogfmtFormat()
		}
	case "terminal":
		return log.TerminalFormat(color)
	case "logfmt":
		return log.LogfmtFormat()
	default:
		panic("Failed to create `log.Format` from options")
	}
}

// Level parses the level string into an appropriate object
func Level(s string) log.Lvl {
	s = strings.ToLower(s) // ignore case
	l, err := log.LvlFromString(s)
	if err != nil {
		panic(fmt.Sprintf("Could not parse log level: %v", err))
	}
	return l
}
