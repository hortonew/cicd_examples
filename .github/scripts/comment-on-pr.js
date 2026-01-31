/**
 * Comment on PR with Kustomize diff results
 * 
 * Usage in workflow:
 *   - uses: actions/github-script@v8
 *     with:
 *       script: |
 *         const script = require('./.github/scripts/comment-on-pr.js')
 *         await script({github, context, core, inputs})
 */

const fs = require('fs');

module.exports = async ({ github, context, core, inputs }) => {
    const {
        environments,
        changedFiles,
        kubeconformEnabled,
        validationFailed
    } = inputs;

    const diff = fs.readFileSync('diff_output.md', 'utf8');
    const envs = environments.split(' ').join(', ');

    let validationSection = '';
    if (kubeconformEnabled) {
        const validation = fs.readFileSync('validation_output.md', 'utf8');
        validationSection = `### Validation ${validationFailed ? '❌' : '✅'}\n\n${validation}\n\n`;
    }

    const files = changedFiles.split(',').filter(f => f);
    const filesSection = files.length > 0
        ? `### Files Changed\n\n${files.map(f => '- \`' + f + '\`').join('\n')}\n\n`
        : '';

    const body = `## Kustomize Diff

Environments affected: \`${envs}\`

${filesSection}${validationSection}### Changes

${diff}
`;

    // Find existing comment
    const { data: comments } = await github.rest.issues.listComments({
        owner: context.repo.owner,
        repo: context.repo.repo,
        issue_number: context.issue.number,
    });

    const botComment = comments.find(c =>
        c.user.type === 'Bot' && c.body.includes('## Kustomize Diff')
    );

    if (botComment) {
        await github.rest.issues.updateComment({
            owner: context.repo.owner,
            repo: context.repo.repo,
            comment_id: botComment.id,
            body: body
        });
        core.info(`Updated existing comment ${botComment.id}`);
    } else {
        await github.rest.issues.createComment({
            owner: context.repo.owner,
            repo: context.repo.repo,
            issue_number: context.issue.number,
            body: body
        });
        core.info('Created new comment');
    }
};
