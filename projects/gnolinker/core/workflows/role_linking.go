package workflows

import (
	"encoding/base64"
	"fmt"
	"time"

	"github.com/allinbits/labs/projects/gnolinker/core"
	"github.com/allinbits/labs/projects/gnolinker/core/contracts"
	"golang.org/x/crypto/nacl/sign"
)

// RoleLinkingWorkflowImpl implements the role linking workflow
type RoleLinkingWorkflowImpl struct {
	gnoClient *contracts.GnoClient
	config    WorkflowConfig
}

// NewRoleLinkingWorkflow creates a new role linking workflow
func NewRoleLinkingWorkflow(client *contracts.GnoClient, config WorkflowConfig) RoleLinkingWorkflow {
	return &RoleLinkingWorkflowImpl{
		gnoClient: client,
		config:    config,
	}
}

// GenerateClaim creates a signed claim for linking a realm role to a platform role
func (w *RoleLinkingWorkflowImpl) GenerateClaim(userID, platformGuildID, platformRoleID, roleName, realmPath string) (*core.Claim, error) {
	// Get the user's linked Gno address for the claim
	gnoAddress, err := w.gnoClient.GetLinkedAddress(userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get linked address: %w", err)
	}

	if gnoAddress == "" {
		return nil, fmt.Errorf("user has not linked their Gno address")
	}

	// Generate the claim
	timestamp := time.Now()
	message := fmt.Sprintf("%v,%v,%v,%v,%v,%v,%v",
		timestamp.Unix(), userID, platformGuildID, platformRoleID, gnoAddress, roleName, realmPath)
	signedMessage := sign.Sign(nil, []byte(message), w.config.SigningKey)
	signature := base64.RawURLEncoding.EncodeToString(signedMessage)

	return &core.Claim{
		Type:      core.ClaimTypeRoleLink,
		Data:      message,
		Signature: signature,
		CreatedAt: timestamp,
	}, nil
}

// GenerateUnlinkClaim creates a signed claim for unlinking a realm role from a platform role
func (w *RoleLinkingWorkflowImpl) GenerateUnlinkClaim(userID, platformGuildID, platformRoleID, roleName, realmPath string) (*core.Claim, error) {
	// Get the user's linked Gno address for the claim
	gnoAddress, err := w.gnoClient.GetLinkedAddress(userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get linked address: %w", err)
	}

	if gnoAddress == "" {
		return nil, fmt.Errorf("user has not linked their Gno address")
	}

	// Generate the unlink claim
	timestamp := time.Now()
	message := fmt.Sprintf("%v,%v,%v,%v,%v,%v,%v",
		timestamp.Unix(), userID, platformGuildID, platformRoleID, gnoAddress, roleName, realmPath)
	signedMessage := sign.Sign(nil, []byte(message), w.config.SigningKey)
	signature := base64.RawURLEncoding.EncodeToString(signedMessage)

	return &core.Claim{
		Type:      core.ClaimTypeRoleUnlink,
		Data:      message,
		Signature: signature,
		CreatedAt: timestamp,
	}, nil
}

// GetLinkedRole retrieves the role mapping for a specific realm role
func (w *RoleLinkingWorkflowImpl) GetLinkedRole(realmPath, roleName, platformGuildID string) (*core.RoleMapping, error) {
	return w.gnoClient.GetLinkedRole(realmPath, roleName, platformGuildID)
}

// ListLinkedRoles retrieves all role mappings for a realm
func (w *RoleLinkingWorkflowImpl) ListLinkedRoles(realmPath, platformGuildID string) ([]*core.RoleMapping, error) {
	return w.gnoClient.ListLinkedRoles(realmPath, platformGuildID)
}

// ListAllRolesByGuild retrieves all role mappings for a guild across all realms
func (w *RoleLinkingWorkflowImpl) ListAllRolesByGuild(platformGuildID string) ([]*core.RoleMapping, error) {
	return w.gnoClient.ListAllRolesByGuild(platformGuildID)
}

// HasRealmRole checks if an address has a specific role in the realm
func (w *RoleLinkingWorkflowImpl) HasRealmRole(realmPath, roleName, address string) (bool, error) {
	return w.gnoClient.HasRole(realmPath, roleName, address)
}

// GetClaimURL returns the URL where admins can submit their claim
func (w *RoleLinkingWorkflowImpl) GetClaimURL(claim *core.Claim) string {
	// Format: https://baseurl/r/linker000/discord/role/v0:claim/signature
	url := fmt.Sprintf("%s/%s:claim/%s", w.config.BaseURL, w.config.RoleContract, claim.Signature)

	// Add query parameter for unlink operations
	if claim.Type == core.ClaimTypeRoleUnlink {
		url += "?unlink=true"
	}

	return url
}
